# Copyrights 2003-2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.00.

package OODoc::Parser;
use vars '$VERSION';
$VERSION = '1.00';
use base 'OODoc::Object';

use strict;
use warnings;

use Carp;


#-------------------------------------------


sub parse(@) { confess }

#-------------------------------------------


#-------------------------------------------


sub cleanup($$$)
{   my ($self, $formatter, $manual, $string) = @_;

    return $self->cleanupPod($formatter, $manual, $string)
       if $formatter->isa('OODoc::Format::Pod');

    return $self->cleanupHtml($formatter, $manual, $string)
       if $formatter->isa('OODoc::Format::Html');

    croak "ERROR: The formatter type ".ref($formatter)
        . " is not known for cleanup\n";

    $string;
}


1;

