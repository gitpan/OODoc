
package OODoc::Text::SubSection;
use vars '$VERSION';
$VERSION = '0.04';
use base 'OODoc::Text::Structure';

use strict;
use warnings;

use Carp;


#-------------------------------------------


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $args->{type}      ||= 'Subsection';
    $args->{container} ||= delete $args->{section} or confess;
    $args->{level}     ||= 3;

    $self->SUPER::init($args) or return;

    $self;
}

#-------------------------------------------

sub path()
{   my $self = shift;
    $self->section->path . '/' . $self->name;
}

#-------------------------------------------


#-------------------------------------------


sub section() { shift->container }

#-------------------------------------------


sub chapter() { shift->section->chapter }

#-------------------------------------------

1;
