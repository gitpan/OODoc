# Copyrights 2003-2008 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.04.

package OODoc::Text::Example;
use vars '$VERSION';
$VERSION = '1.04';

use base 'OODoc::Text';

use strict;
use warnings;

use Carp;


sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Example';
    $args->{container} = delete $args->{container} or confess;

    $self->SUPER::init($args) or return;

    $self;
}

#-------------------------------------------

1;
