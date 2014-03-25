use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package IO::Async::XMLStream::SAXReader::DuckHandler;

# ABSTRACT: Deferred Handler proxy for IO::Async constructor-driven interface

# AUTHORITY

use Scalar::Util qw(weaken);
use Carp qw(croak);

=begin Pod::Coverage

new
can

=end Pod::Coverage

=cut

sub new {
  my ( $self, $opts ) = @_;
  croak('SAXReader option is mandatory') unless exists $opts->{SAXReader};
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
    my ( undef, @args ) = @_;
    return $callback->( $sax, @args );
  };
}

sub can {
  my ( $self, $method ) = @_;
  my $orig = $self->SUPER::can($method);
  return $orig if $orig;
  return $self->_dyn_method($method);
}

## no critic (ClassHierarchies::ProhibitAutoloading)
sub AUTOLOAD {
  my ( $self, @args ) = @_;
  ( my $methname = our $AUTOLOAD ) =~ s/.+:://msx;
  return if 'DESTROY' eq $methname;
  return unless my $meth = $self->_dyn_method($methname);
  return $meth->( $self, @args );
}

1;

