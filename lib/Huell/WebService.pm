use v5.36.0;

package Huell::WebService;
use Moose;
use experimental 'signatures';

use Huell::Agent;
use JSON::MaybeXS;
use Plack::Request;
use Plack::Response;

has config_file => (
  is => 'ro',
  isa => 'Str',
  default => sub {
    $ENV{HUELL_CONFIG} // die "no config file and no \$HUELL_CONFIG"
  },
);

has agent => (
  is    => 'ro',
  isa   => 'Huell::Agent',
  lazy  => 1,
  default => sub ($self) {
    return Huell::Agent->from_config_file($self->config_file);
  },
);

has _rooms_cache => (
  is => 'rw',
);

sub room_named ($self, $name) {
  my $cache = $self->_rooms_cache;

  if (!$cache || time - $cache->{cached_at} > 300) {
    my @rooms = $self->agent->get_rooms->get;
    $cache = { cached_at => time, rooms => \@rooms };
    $self->_rooms_cache($cache);
  }

  my ($room) = grep {; $_->name eq $name } $cache->{rooms}->@*;

  return $room;
}

sub to_app ($self) {
  my $agent = Huell::Agent->from_config_file($self->config_file);
  my $JSON  = JSON::MaybeXS->new;

  return sub ($env) {
    my $req = Plack::Request->new($env);

    unless ($req->method eq 'PUT' && $req->path eq '/lights') {
      return [
        '400',
        [ 'Content-Type', 'application/json' ],
        [ qq[{"ok":false,"error":"bogus path/method"}\n] ],
      ];
    }

    my $payload = $JSON->decode($req->raw_body);

    my $room = $self->room_named($payload->{room});

    unless ($room) {
      return [
        '400',
        [ 'Content-Type', 'application/json' ],
        [ qq[{"ok":false,"error":"no such room"}\n] ],
      ];
    }

    my $preset = $agent->preset_named($payload->{preset});

    unless ($preset) {
      return [
        '400',
        [ 'Content-Type', 'application/json' ],
        [ qq[{"ok":false,"error":"no such preset"}\n] ],
      ];
    }

    my $res = $room->set_state($preset)->get;

    return [
      '202',
      [ 'Content-Type', 'application/json' ],
      [ qq[{"ok":true,"description":"I've passed along the request."}\n] ],
    ];
  }
}

1;
