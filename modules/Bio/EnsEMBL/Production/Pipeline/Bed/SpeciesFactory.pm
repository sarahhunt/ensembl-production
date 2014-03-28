=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::SpeciesFactory;

use strict;
use warnings;
use Bio::EnsEMBL::Registry;

use base qw/Bio::EnsEMBL::Hive::RunnableDB::JobFactory/;

sub param_defaults {
  my ($self) = @_;
  return {
    species => [],
    column_names => [qw/name/],
  };
}

sub fetch_input {
  my ($self) = @_;

  my $species_lookup = {
    map { $_ => 1 } 
    map { Bio::EnsEMBL::Registry->get_alias($_)  } 
    @{$self->param('species')}
  };

  my $dbas = Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'core');
  my @inputlist;
  foreach my $dba (@{$dbas}) {
    if(!$self->process_dba($dba, $species_lookup)) {
      next;
    }
    push(@inputlist, $dba->get_MetaContainer()->get_production_name());
    $dba->dbc()->disconnect_if_idle();
  }
  $self->param('inputlist', \@inputlist);
  return 1;
}

sub process_dba {
  my ($self, $dba, $species_lookup) = @_;
  
  #Reject if DB was ancestral sequences
  return 0 if $dba->species() =~ /ancestral/i;
  return 1 if $self->param('force');
  
  #If species is defined then make sure we only allow those species through
  if(%{$species_lookup}) {
    my $name = $dba->species();
    my $aliases = Bio::EnsEMBL::Registry->get_all_aliases($name);
    push(@{$aliases}, $name);
    my $found = 0;
    foreach my $alias (@{$aliases}) {
      if($species_lookup->{$alias}) {
        $found = 1;
        last;
      }
    }
    return $found;
  }
  
  #Otherwise just accept
  return 1;
}

1;
