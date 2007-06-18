# Copyrights 2003-2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.01.

package OODoc::Format::Pod2;
use vars '$VERSION';
$VERSION = '1.01';
use base 'OODoc::Format::Pod';

use strict;
use warnings;

use Carp;
use File::Spec;
use IO::Scalar;

use Template::Magic;


my $default_template;
{   local $/;
    $default_template = <DATA>;
    close DATA;
}

sub createManual(@)
{   my ($self, %args) = @_;
    $self->{O_template} = delete $args{template} || \$default_template;
    $self->SUPER::createManual(%args) or return;
}

sub formatManual(@)
{   my ($self, %args) = @_;
    my $output    = delete $args{output};

    my %permitted =
     ( chapter     => sub {$self->templateChapter(shift, \%args) }
     , inheritance => sub {$self->templateInheritance(shift, \%args) }
     , diagnostics => sub {$self->templateDiagnostics(shift, \%args) }
     , append      => sub {$self->templateAppend(shift, \%args) }
     , comment     => sub { '' }
     );

    my $template  = Template::Magic->new
     ( { -lookups => \%permitted }
     );

    my $layout  = ${$self->{O_template}};        # Copy needed by template!
    my $created = $template->output(\$layout);
    $output->print($$created);
}


sub templateChapter($$)
{   my ($self, $zone, $args) = @_;
    my $contained = $zone->content;
    warn "WARNING: no meaning for container $contained in chapter block\n"
        if defined $contained && length $contained;

    my $attrs = $zone->attributes;
    my $name  = $attrs =~ s/^\s*(\w+)\s*\,?// ? $1 : undef;

    croak "ERROR: chapter without name in template.", return ''
       unless defined $name;

    my @attrs = $self->zoneGetParameters($attrs);
    my $out   = '';

    $self->showOptionalChapter($name, %$args,
       output => IO::Scalar->new(\$out), @attrs);

    $out;
}

sub templateInheritance($$)
{   my ($self, $zone, $args) = @_;
    my $out   = '';
    $self->chapterInheritance(%$args, output => IO::Scalar->new(\$out));
    $out;
}

sub templateDiagnostics($$)
{   my ($self, $zone, $args) = @_;
    my $out   = '';
    $self->chapterDiagnostics(%$args, output => IO::Scalar->new(\$out));
    $out;
}

sub templateAppend($$)
{   my ($self, $zone, $args) = @_;
    my $out   = '';
    $self->showAppend(%$args, output => IO::Scalar->new(\$out));
    $out;
}


1;

__DATA__
{chapter NAME}
{inheritance}
{chapter SYNOPSIS}
{chapter DESCRIPTION}
{chapter OVERLOADED}
{chapter METHODS}
{chapter FUNCTIONS}
{chapter EXPORTS}
{chapter DETAILS}
{diagnostics}
{chapter REFERENCES}
{chapter COPYRIGHTS}
{comment In stead of append you can also add texts directly}
{append}
