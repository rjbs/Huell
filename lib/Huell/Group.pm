use v5.32.0;
use warnings;

package Huell::Group;
use Moose;

use experimental 'signatures';

use Future::AsyncAwait;

has _agent => (is => 'ro', isa => 'Huell::Agent', required => 1);

has id => (is => 'ro', isa => 'Str', required => 1);

has _attrs => (is => 'ro', isa => 'HashRef', required => 1);

sub name ($self) { $self->_attrs->{name} }

async sub set_state ($self, $state) {
  my $id = $self->id;
  await $self->_agent->post("/groups/$id/action", $state);
}

no Moose;
__PACKAGE__->meta->make_immutable;
