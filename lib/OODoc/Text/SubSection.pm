# Copyrights 2003-2006 by Mark Overmeer. For contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc .

package OODoc::Text::SubSection;
use vars '$VERSION';
$VERSION = '0.96';
use base 'OODoc::Text::Structure';

use strict;
use warnings;

use Carp;


sub init($)
{   my ($self, $args) = @_;
    $args->{type}      ||= 'Subsection';
    $args->{container} ||= delete $args->{section} or confess;
    $args->{level}     ||= 3;

    $self->SUPER::init($args) or return;

    $self;
}

#-------------------------------------------

sub findEntry($)
{  my ($self, $name) = @_;
   $self->name eq $name ? $self : ();
}

#-------------------------------------------


sub section() { shift->container }

#-------------------------------------------


sub chapter() { shift->section->chapter }

#-------------------------------------------

sub path()
{   my $self = shift;
    $self->section->path . '/' . $self->name;
}

#-------------------------------------------

1;
