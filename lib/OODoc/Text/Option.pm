# Copyrights 2003-2008 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.04.

package OODoc::Text::Option;
use vars '$VERSION';
$VERSION = '1.04';

use base 'OODoc::Text';

use strict;
use warnings;

use Carp;


sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Option';
    $args->{container} = delete $args->{subroutine} or confess;

    $self->SUPER::init($args) or return;

    $self->{OTO_parameters} = delete $args->{parameters} or confess;

    $self;
}

#-------------------------------------------


sub subroutine() { shift->container }

#-------------------------------------------


sub parameters() { shift->{OTO_parameters} }

#-------------------------------------------

1;
