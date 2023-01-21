use v5.32.0;
use warnings;

package Huell::Room;
use Moose;

use experimental 'signatures';

use Future::AsyncAwait;

has _agent => (is => 'ro', isa => 'Huell::Agent', required => 1);

has _attrs => (is => 'ro', isa => 'HashRef', required => 1);

sub id   ($self) { $self->_attrs->{id} }
sub name ($self) { $self->_attrs->{metadata}{name} }

sub group_id ($self) {
  my ($group) = grep {; $_->{rtype} eq 'grouped_light' }
                $self->_attrs->{services}->@*;

  return $group->{rid};
}

async sub set_state ($self, $state) {
  my $group_id = $self->group_id;
  await $self->_agent->put("/resource/grouped_light/$group_id", $state);
}

no Moose;
__PACKAGE__->meta->make_immutable;
