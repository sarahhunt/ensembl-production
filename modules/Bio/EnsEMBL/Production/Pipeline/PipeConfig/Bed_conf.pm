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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::Bed_conf;

use strict;
use warnings;
use Bio::EnsEMBL::ApiVersion qw/software_version/;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub default_options {
  my ($self) = @_;

  return {
    # inherit other stuff from the base class
    %{ $self->SUPER::default_options() }, 

    ### OVERRIDE
    # base_path => '',

    ### Optional overrides        
    species => [],

    force => 0,

    release => software_version(),
    
    bed_to_big_bed => 'bedToBigBed',
    bgzip => 'bgzip',
    tabix => 'tabix',

    ### Defaults 

    pipeline_name => 'bed_dump_'.$self->o('release'),

    # email => $self->o('ENV', 'USER').'@ebi.ac.uk',
  };
}

## See diagram for pipeline structure 
sub pipeline_analyses {
  my ($self) = @_;

  my $bed_flow = { 'species' => '#species#' };
  my $bigbed_flow = { 'species' => '#species#', 'type' => '#type#', 'bed' => '#bed#'};
  my $tabix_flow = { 'species' => '#species#', 'bed' => '#bed#'};

  return [
    {
      -logic_name => 'ScheduleSpecies',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::SpeciesFactory',
      -parameters => {
        species => $self->o('species'),
        force => $self->o('force')
      },
      -input_ids  => [ {} ],
      -flow_into  => {
        1 => {'ChromSizes' => { 'species' => '#name#' }},
      },
    },

    {
      -logic_name => 'ChromSizes',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::ChromSizes',
      -flow_into => {
        1 => { 'Repeats' =>  $bed_flow, 'Transcripts' => $bed_flow}
      },
    },

    {
      -logic_name => 'Repeats',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::DumpRepeats',
      -flow_into => {
        1 => { 'BedToBigBed' => $bigbed_flow, 'Tabix' => $tabix_flow }
      },
    },

    {
      -logic_name => 'Transcripts',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::DumpTranscripts',
      -flow_into => {
        1 => { 'BedToBigBed' => $bigbed_flow, 'Tabix' => $tabix_flow }
      },
    },

    {
      -logic_name => 'BedToBigBed',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::BedToBigBed',
      -parameters => { bed_to_big_bed => $self->o('bed_to_big_bed') },
    },

    {
      -logic_name => 'Tabix',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::Tabix',
      -parameters => { bgzip => $self->o('bgzip'), tabix => $self->o('tabix') },
    },

  ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;    
    return {
        %{ $self->SUPER::pipeline_wide_parameters() },  # inherit other stuff from the base class
        base_path => $self->o('base_path'),
    };
}

# override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
    my $self = shift;
    return "-reg_conf ".$self->o("registry");
}

sub resource_classes {
    my $self = shift;
    return {
      'default'  => { LSF => '-q normal -M2000 -R"select[mem>2000] rusage[mem=2000]"' },
    }
}

1;
