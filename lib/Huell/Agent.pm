use v5.32.0;
use warnings;

package Huell::Agent;
use Moose;

use experimental 'signatures';

use Future::AsyncAwait;
use Huell::Group;
use Huell::Util qw(rgb_to_xy);
use IO::Async::Loop;
use IO::Socket::SSL qw( SSL_VERIFY_NONE );
use JSON::MaybeXS;
use Net::Async::HTTP;
use URI;
use YAML::XS ();

sub from_config_file ($class, $filename) {
  local $YAML::XS::Boolean = 'JSON::PP';
  my $config = YAML::XS::LoadFile($filename);

  return $class->new({
    address   => $config->{address},
    username  => $config->{username},
    presets   => $config->{presets},
  });
}

has address   => (is => 'ro', isa => 'Str',     required => 1);
has username  => (is => 'ro', isa => 'Str',     required => 1);
has presets   => (is => 'ro', isa => 'HashRef', required => 1);

sub preset_named ($self, $name) {
  my $presets = $self->presets;
  return unless $presets->{ $name };

  return $self->state($presets->{$name});
}

async sub get_groups ($self) {
  my $data = await $self->get('/groups');

  my @groups = map {;
    Huell::Group->new({
      id      => $_,
      _attrs  => $data->{$_},
      _agent  => $self,
    })
  } keys %$data;

  return @groups;
}

has _http => (
  is => 'ro',
  lazy  => 1,
  default => sub {
    my $loop = IO::Async::Loop->new;
    my $http = Net::Async::HTTP->new(
      SSL_verify_mode => SSL_VERIFY_NONE,
    );

    $loop->add($http);

    return $http;
  },
);

sub state ($self, $input_attr) {
  my %attr = %$input_attr;

  if (my $rgb = delete $attr{rgb}) {
    $attr{xy} = rgb_to_xy(@$rgb);
  }

  return {
    on        => \1,
    bri       => 254,
    colormode => 'xy',
    alert     => 'none',
    effect    => 'none',
    %attr,
  };
}

sub _url ($self, $path) {
  my $address   = $self->address;
  my $username  = $self->username;

  return "https://$address/api/$username$path";
}

async sub get ($self, $path) {
  my $res = await $self->_http->do_request(
    method  => 'GET',
    uri     => $self->_url($path),
  );

  unless ($res->is_success) {
    die "hue get failed";
  }

  return JSON::MaybeXS->new->decode(
    $res->decoded_content(charset => 'undef'),
  );
}

async sub post ($self, $path, $content) {
  my $res = await $self->_http->do_request(
    method  => 'PUT',
    uri     => $self->_url($path),
    content => JSON::MaybeXS->new->encode($content),
    content_type => 'application/json',
  );

  unless ($res->is_success) {
    die "hue post failed";
  }

  return JSON::MaybeXS->new->decode($res->decoded_content(charset => undef));
}

no Moose;
__PACKAGE__->meta->make_immutable;
