use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package IO::Async::XMLStream::SAXReader;

# ABSTRACT: Dispatch SAX events from an XML stream.

# AUTHORITY

use parent 'IO::Async::Stream';

=head1 SYNOPSIS

    use IO::Async::XMLStream::SAXReader;
    use IO::Async::Loop;

    my $loop = IO::Async::Loop->new();

    my $sax  = IO::Async::XMLStream::SAXReader->new(
        handle => $SOME_IO_HANDLE,
        on_start_document => sub {
            my ( $saxreader, @args ) = @_;
            ...
        },
        on_start_element  => sub {
            my ( $saxreader, @args ) = @_;
            ...
        },
        on_end_document => sub {
            $loop->stop;
        },
    );

    $loop->add($sax);
    $loop->run();

This sub-classes L<< C<IO::Async::Stream>|IO::Async::Stream >> to provide a streaming SAX parser.

For the individual C<SAX> events that can be listened for, see L<< C<XML::SAX::Base>|XML::SAX::Base >>.

All are prefixed with the C<on_> prefix as constructor arguments.

=cut

use XML::LibXML::SAX::ChunkParser 0.00007;    # Buggy Finish

## no critic (NamingConventions)
sub _SAXReader {
  my ($self) = @_;
  my $key = 'SAXReader';
  return $self->{$key} if exists $self->{$key};
  $self->{$key} = {};
  $self->{$key}->{Parser} = XML::LibXML::SAX::ChunkParser->new( Handler => $self->{sax_handler} );
  return $self->{$key};
}
## use critic

my @XML_METHODS = qw(
  attlist_decl
  attribute_decl
  characters
  comment
  doctype_decl
  element_decl
  end_cdata
  end_document
  end_dtd
  end_element
  end_entity
  end_prefix_mapping
  entity_decl
  entity_reference
  error
  external_entity_decl
  fatal_error
  ignorable_whitespace
  internal_entity_decl
  notation_decl
  processing_instruction
  resolve_entity
  set_document_locator
  skipped_entity
  start_cdata
  start_document
  start_dtd
  start_element
  start_entity
  start_prefix_mapping
  unparsed_entity_decl
  warning
  xml_decl
);

sub configure {
  my ( $self, %params ) = @_;

  for my $method ('sax_handler') {
    next unless exists $params{$method};
    $self->{$method} = delete $params{$method};
  }

  if ( not $self->{'sax_handler'} ) {
    $self->{'sax_handler'} = IO::Async::XMLStream::SAXReader::DuckHandler->new( { SAXReader => $self, }, );
    for my $method (@XML_METHODS) {
      next unless exists $params{ 'on_' . $method };
      $self->{ 'on_' . $method } = delete $params{ 'on_' . $method };
    }
  }
  $self->_SAXReader;
  return $self->SUPER::configure(%params);
}

sub on_read {
  my ( $self, $buffref, $eof ) = @_;
  my $text = substr ${$buffref}, 0, length ${$buffref}, q[];

  $self->_SAXReader->{Parser}->parse_chunk($text) if length $text;
  if ($eof) {
    $self->_SAXReader->{Parser}->finish;
    return 0;
  }
  return 1;
}

package    ##  Hide
  IO::Async::XMLStream::SAXReader::DuckHandler;

use Scalar::Util qw(weaken);

sub new {
  my ( $self, $opts ) = @_;
  die unless exists $opts->{SAXReader};
  weaken $opts->{SAXReader};
  return bless $opts, $self;
}

sub _dyn_method {
  my ( $self, $method ) = @_;
  my $sax      = $self->{SAXReader};
  my $event    = 'on_' . $method;
  my $callback = $sax->can_event($event);
  return unless $callback;
  return sub {
    my ( $self, @args ) = @_;
    return $callback->( $sax, @args );
  };
}

sub can {
  my ( $self, $method ) = @_;
  my $orig = $self->SUPER::can($method);
  return $orig if $orig;
  return $self->_dyn_method($method);
}

sub AUTOLOAD {
  my ( $self, @args ) = @_;
  ( my $methname = our $AUTOLOAD ) =~ s/.+:://;
  return if $methname eq 'DESTROY';
  return unless my $meth = $self->_dyn_method($methname);
  return $meth->( $self, @args );
}

1;
