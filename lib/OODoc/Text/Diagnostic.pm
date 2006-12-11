# Copyrights 2003-2006 by Mark Overmeer. For contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc .

package OODoc::Text::Diagnostic;
use vars '$VERSION';
$VERSION = '0.96';
use base 'OODoc::Text';

use strict;
use warnings;

use Carp;


sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Diagnostic';
    $args->{container} = delete $args->{subroutine} or confess;

    $self->SUPER::init($args) or return;

    $self;
}

#-------------------------------------------


sub subroutine() { shift->container }

#-------------------------------------------

1;
