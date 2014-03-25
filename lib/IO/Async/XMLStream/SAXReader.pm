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

sub _init {
  my ($self) = @_;
  $self->SUPER::_init;
  $self->_SAXReader;
  return $self;
}

## no critic (NamingConventions)
sub _SAXReader {
  my ($self) = @_;
  my $key = 'SAXReader';
  return $self->{$key} if exists $self->{$key};
  $self->{$key} = {};
  $self->{$key}->{Parser} = XML::LibXML::SAX::ChunkParser->new();
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

sub _set_handler {
  my ( $self, $method, $callback ) = @_;
  if ( not defined $callback ) {
    return $self->_clear_handler($method);
  }
  $self->{ 'on_' . $method } = $callback;
  $self->_SAXReader->{Parser}->{Methods}->{$method} = sub {
    my (@args) = @_;
    $self->invoke_event( 'on_' . $method, @args );
  };
  return $self;
}

sub _clear_handler {
  my ( $self, $method ) = @_;
  delete $self->_SAXReader->{Parser}->{Methods}->{$method};
  delete $self->{ 'on_' . $method };
  return $self;
}

sub configure {
  my ( $self, %params ) = @_;
  for my $method (@XML_METHODS) {
    next unless exists $params{ 'on_' . $method };
    my $cb = delete $params{ 'on_' . $method };
    $self->_set_handler( $method, $cb );
  }
  for my $method (@XML_METHODS) {
    next unless my $callback = $self->can( 'on_' . $method );
    $self->_set_handler( $method, $callback );
  }
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

1;
