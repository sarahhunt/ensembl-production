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

    # Specify what locations you want to dump. 
    # Remember if you run over more than one species all locations must exist
    locations => [],

    # Specify the species to use
    species => [],

    # Force the running of anything
    force => 0,
    release => software_version(),
    
    # Binaries
    bed_to_big_bed => 'bedToBigBed',
    bgzip => 'bgzip',
    tabix => 'tabix',

    # Compara db is multi by default
    compara => 'multi',

    # Always force the flow to genebuild because of display ids
    force_flow => ['genebuild'],

    ### Defaults

    pipeline_name => 'bed_dump_'.$self->o('release'),

    # email => $self->o('ENV', 'USER').'@ebi.ac.uk',
  };
}

## See diagram for pipeline structure 
sub pipeline_analyses {
  my ($self) = @_;

  my $bed_flow    = { 'species' => '#species#' };
  my $bigbed_flow = { 1 => { 
    'BedToBigBed' => { 
      'species'         => '#species#', 
      'bed_type'        => '#bed_type#', 
      'bed'             => '#bed#', 
      'autosql'         => '#autosql#', 
      'bigbed_indexes'  => '#bigbed_indexes#'
    },
    # Accumulators require the flow param hash to have a key which matches the acummulator key.
    # Here we've got a key called track which will be holding an Array. The second flow hash
    # holds the data we will push into the track array and this is keyed by "track" as well.
    ':////accu?track=[]' => { track => { def => '#def#', species => '#species#' } } 
  }};

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
        '2->A' => ['ChromSizes'],
        'A->1' => ['BuildTrackHub'],
      },
    },

    {
      -logic_name => 'ChromSizes',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::ChromSizes',
      -flow_into  => { 1 => ['ProductionFlow'] },
    },

    {
      -logic_name => 'ProductionFlow',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::ProductionFlow',
      -parameters => { force_flow => $self->o('force_flow') },
      -flow_into  => {
        1 => ['ConstrainedElements', ':////accu?input_species={species}'], #Flow to no-matter what
        # 2 => [''],      #Assembly based updates
        3 => ['Repeats'],     #Repeat based updates
        4 => ['Transcripts'], #Gene based updates
      },
    },

    {
      -logic_name => 'Repeats',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::DumpRepeats',
      -flow_into => $bigbed_flow,
    },

    {
      -logic_name => 'Transcripts',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::DumpTranscripts',
      -flow_into => $bigbed_flow,
    },

    {
      -logic_name => 'ConstrainedElements',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::DumpConstrainedElements',
      -parameters => {
        compara => $self->o('compara'),
      },
      -flow_into => $bigbed_flow,
    },

    {
      -logic_name => 'BedToBigBed',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::BedToBigBed',
      -parameters => { bed_to_big_bed => $self->o('bed_to_big_bed') },
      -flow_into => { 
        1 => { 
          'Tabix' => { 'species' => '#species#', 'bed' => '#bed#' },
        } 
      }
    },

    # Tabix only gets the data after successful bigbed runs otherwise it "steals" the file via gzip
    {
      -logic_name => 'Tabix',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::Tabix',
      -parameters => { bgzip => $self->o('bgzip'), tabix => $self->o('tabix') },
    },

    {
      -logic_name => 'BuildTrackHub',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Bed::BuildTrackHub',
    },

  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;    
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },  # inherit other stuff from the base class
    base_path => $self->o('base_path'),
    release => $self->o('release'),
    force => $self->o('force'),
    locations => $self->o('locations'),
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
      'default'  => { LSF => '-q normal -M4000 -R"select[mem>4000] rusage[mem=4000]"' },
    }
}

1;
