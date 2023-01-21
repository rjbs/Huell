use v5.36.0;

package Huell::Agent;
use Moose;

use experimental 'signatures';

use Future::AsyncAwait;
use Huell::Room;
use Huell::Util qw(rgb_to_xy);
use IO::Async::Loop;
use IO::Socket::SSL qw( SSL_VERIFY_NONE );
use JSON::MaybeXS;
use Net::Async::HTTP;
use URI;
use YAML::XS ();

sub from_config_file ($class, $filename) {
  my $config = YAML::XS::LoadFile($filename);

  return $class->new({
    address   => $config->{address},
    key       => $config->{key},
    presets   => $config->{presets},
  });
}

has address => (is => 'ro', isa => 'Str',     required => 1);
has key     => (is => 'ro', isa => 'Str',     required => 1);
has presets => (is => 'ro', isa => 'HashRef', required => 1);

sub preset_named ($self, $name) {
  my $presets = $self->presets;
  return unless $presets->{ $name };

  return $self->state($presets->{$name});
}

async sub get_rooms ($self) {
  my $payload = await $self->get('/resource/room');

  my @room_data = $payload->{data}->@*;

  my @rooms = map {;
    Huell::Room->new({
      _attrs  => $_,
      _agent  => $self,
    })
  } @room_data;

  return @rooms;
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

  if (my $xy = $attr{xy}) {
    my %color;
    @color{qw(x y)} = @$xy;

    $attr{color} = { xy => \%color };
  }

  if (exists $attr{on}) {
    $attr{on} = { on => ($attr{on} ? JSON->true : JSON->false) };
  }

  return {
    on        => { on => \1 },
    dimming   => { brightness => 100 },
    # alert     => 'none',
    # effect    => 'none',
    %attr,
  };
}

sub _url ($self, $path) {
  my $address = $self->address;

  return "https://$address/clip/v2$path";
}

async sub get ($self, $path) {
  my $res = await $self->_http->do_request(
    method  => 'GET',
    uri     => $self->_url($path),
    headers => [
      'hue-application-key' => $self->key,
    ],
  );

  unless ($res->is_success) {
    die "hue get failed";
  }

  return JSON::MaybeXS->new->decode(
    $res->decoded_content(charset => 'undef'),
  );
}

async sub put ($self, $path, $content) {
  my $res = await $self->_http->do_request(
    method  => 'PUT',
    uri     => $self->_url($path),
    content => JSON::MaybeXS->new->encode($content),
    content_type => 'application/json',
    headers => [
      'hue-application-key' => $self->key,
    ],
  );

  unless ($res->is_success) {
    warn $res->as_string;
    die "hue put failed";
  }

  return JSON::MaybeXS->new->decode($res->decoded_content(charset => undef));
}

no Moose;
__PACKAGE__->meta->make_immutable;
