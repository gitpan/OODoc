
package OODoc::Format;
use vars '$VERSION';
$VERSION = '0.06';
use base 'OODoc::Object';

use strict;
use warnings;

use Carp;
use OODoc::Manifest;


#-------------------------------------------


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    $self->{OF_project} = delete $args->{project}
        or croak "ERROR: formatter knows no project name.\n";

    $self->{OF_version} = delete $args->{version}
        or croak "ERROR: formatter does not know the version.\n";

    $self->{OF_workdir} = delete $args->{workdir}
        or croak "ERROR: no working directory specified.\n";

    $self->{OF_manifest} = delete $args->{manifest} || OODoc::Manifest->new;

    $self;
}

#-------------------------------------------


sub project() {shift->{OF_project}}

#-------------------------------------------


sub version() {shift->{OF_version}}

#-------------------------------------------


sub workdir() {shift->{OF_workdir}}

#-------------------------------------------


sub manifest() {shift->{OF_manifest}}

#-------------------------------------------


#-------------------------------------------


sub createManual(@) { confess }

#-------------------------------------------


sub cleanup($$)
{   my ($self, $manual, $string) = @_;
    $manual->parser->cleanup($self, $manual, $string);
}

#-------------------------------------------


sub showChapter(@)
{   my ($self, %args) = @_;
    my $chapter  = $args{chapter} or confess;
    my $manual   = $args{manual}  or confess;
    my $show_ch  = $args{show_inherited_chapter}    || 'REFER';
    my $show_sec = $args{show_inherited_section}    || 'REFER';
    my $show_ssec= $args{show_inherited_subsection} || 'REFER';

    if($manual->inherited($chapter))
    {    return $self if $show_ch eq 'NO';
         $self->showStructureRefer(%args, structure => $chapter);
         return $self;
    }

    $self->showStructureExpand(%args, structure => $chapter);

    foreach my $section ($chapter->sections)
    {   if($manual->inherited($section))
        {   next if $show_sec eq 'NO';
            $self->showStructureRefer(%args, structure => $section), next
                unless $show_sec eq 'REFER';
        }

        $self->showStructureExpand(%args, structure => $section);

        foreach my $subsection ($section->subsections)
        {   if($manual->inherited($subsection))
            {   next if $show_ssec eq 'NO';
                $self->showStructureRefer(%args, structure=>$subsection), next
                    unless $show_ssec eq 'REFER';
            }

            $self->showStructureExpand(%args, structure => $subsection);
        }
    }
}

#-------------------------------------------


sub showStructureExpanded(@) {confess}

#-------------------------------------------


sub showStructureRefer(@) {confess}

#-------------------------------------------

sub chapterName(@)        {shift->showRequiredChapter(NAME        => @_)}
sub chapterSynopsis(@)    {shift->showOptionalChapter(SYNOPSIS    => @_)}
sub chapterDescription(@) {shift->showRequiredChapter(DESCRIPTION => @_)}
sub chapterOverloaded(@)  {shift->showOptionalChapter(OVERLOADED  => @_)}
sub chapterMethods(@)     {shift->showOptionalChapter(METHODS     => @_)}
sub chapterExports(@)     {shift->showOptionalChapter(EXPORTS     => @_)}
sub chapterDiagnostics(@) {shift->showOptionalChapter(DIAGNOSTICS => @_)}
sub chapterDetails(@)     {shift->showOptionalChapter(DETAILS     => @_)}
sub chapterReferences(@)  {shift->showOptionalChapter(REFERENCES  => @_)}
sub chapterCopyrights(@)  {shift->showOptionalChapter(COPYRIGHTS  => @_)}

#-------------------------------------------


sub showRequiredChapter($@)
{   my ($self, $name, %args) = @_;
    my $manual  = $args{manual} or confess;
    my $chapter = $manual->chapter($name);

    unless(defined $chapter)
    {   warn "WARNING: missing required chapter $name in $manual\n";
        return;
    }

    $self->showChapter(chapter => $chapter, %args);
}

#-------------------------------------------


sub showOptionalChapter($@)
{   my ($self, $name, %args) = @_;
    my $manual  = $args{manual} or confess;

    my $chapter = $manual->chapter($name);
    return unless defined $chapter;

    $self->showChapter(chapter => $chapter, %args);
}

#-------------------------------------------


sub createOtherPages(@) {shift}

#-------------------------------------------


sub showSubroutines(@)
{   my ($self, %args) = @_;

    my @subs   = $args{subroutines} ? sort @{$args{subroutines}} : [];
    return unless @subs;

    my $manual = $args{manual} or confess;
    my $output = $args{output}    || select;

    $args{show_subs_index}        ||= 'NO';
    $args{show_inherited_subs}    ||= 'USE';
    $args{show_described_subs}    ||= 'EXPAND';
    $args{show_option_table}      ||= 'ALL';
    $args{show_inherited_options} ||= 'USE';
    $args{show_described_options} ||= 'EXPAND';

    $self->showSubsIndex(%args, subroutines => \@subs);

    for(my $index=0; $index<@subs; $index++)
    {   my $subroutine = $subs[$index];
        my $show = $manual->inherited($subroutine)
                 ? $args{show_inherited_subs}
                 : $args{show_described_subs};

        $self->showSubroutine 
        ( %args
        , subroutine             => $subroutine
        , show_subroutine        => $show
        , last                   => ($index==$#subs)
        );
    }
}

#-------------------------------------------


sub showSubroutine(@)
{   my ($self, %args) = @_;

    my $subroutine = $args{subroutine} or confess;
    my $manual = $args{manual}         or confess;
    my $output = $args{output}    || select;

    #
    # Method use
    #

    my $use    = $args{show_subroutine} || 'EXPAND';
    my ($show_use, $expand)
     = $use eq 'EXPAND' ? ('showSubroutineUse',  1)
     : $use eq 'USE'    ? ('showSubroutineUse',  0)
     : $use eq 'NAMES'  ? ('showSubroutineName', 0)
     : $use eq 'NO'     ? (undef,                0)
     : croak "ERROR: illegal value for show_subroutine: $use";

    $self->$show_use(%args, subroutine => $subroutine)
       if defined $show_use;
 
    return unless $expand;

    $args{show_inherited_options} ||= 'USE';
    $args{show_described_options} ||= 'EXPAND';

    #
    # Subroutine descriptions
    #

    my $descr       = $args{show_sub_description} || 'DESCRIBED';
    my $description = $subroutine->findDescriptionObject;
    my $show_descr  = 'showSubroutineDescription';

       if(not $description || $descr eq 'NO') { $show_descr = undef }
    elsif($descr eq 'REFER')
    {   $show_descr = 'showSubroutineDescriptionRefer'
           if $manual->inherited($description);
    }
    elsif($descr eq 'DESCRIBED')
         { $show_descr = undef if $manual->inherited($description) }
    elsif($descr eq 'ALL') {;}
    else { croak "ERROR: illegal value for show_sub_description: $descr" }
    
    $self->$show_descr(%args, subroutine => $description)
          if defined $show_descr;

    #
    # Options
    #

    my $options = $subroutine->collectedOptions;

    my $opttab  = $args{show_option_table} || 'NAMES';
    my @options = @{$options}{ sort keys %$options };

    # Option table

    my @opttab
     = $opttab eq 'NO'       ? ()
     : $opttab eq 'DESCRIBED'? (grep {not $manual->inherits($_->[0])} @options)
     : $opttab eq 'INHERITED'? (grep {$manual->inherits($_->[0])} @options)
     : $opttab eq 'ALL'      ? @options
     : croak "ERROR: illegal value for show_option_table: $opttab";
    
    $self->showOptionTable(%args, options => \@opttab)
       if @opttab;

    # Option expanded

    my @optlist;
    foreach (@options)
    {   my ($option, $default) = @$_;
        my $check
          = $manual->inherited($option) ? $args{show_inherited_options}
          :                               $args{show_described_options};
        push @optlist, $_ if $check eq 'USE' || $check eq 'EXPAND';
    }

    $self->showOptions(%args, options => \@optlist)
        if @optlist;

    # Examples

    my @examples = $subroutine->examples;
    my $show_ex  = $args{show_examples} || 'EXPAND';
    $self->showExamples(%args, examples => \@examples)
        if $show_ex eq 'EXPAND';
    
    # Diagnostics

    my @diags    = $subroutine->diagnostics;
    my $show_diag= $args{show_diagnostics} || 'NO';
    $self->showDiagnostics(%args, diagnostics => \@diags)
        if $show_diag eq 'EXPAND';
}

#-------------------------------------------


sub showExamples(@) {shift}

#-------------------------------------------


sub showSubroutineUse(@) {shift}


#-------------------------------------------


sub showSubroutineName(@) {shift}

#-------------------------------------------


sub showSubroutineDescription(@) {shift}

#-------------------------------------------


sub showOptionTable(@)
{   my ($self, %args) = @_;
    my $options = $args{options} or confess;
    my $manual  = $args{manual}  or confess;
    my $output  = $args{output}  or confess;

    my @rows;
    foreach (@$options)
    {   my ($option, $default) = @$_;
        my $optman = $option->manual;
        my $link   = $manual->inherited($option)
                   ? $self->link(undef, $optman)
                   : '';
        push @rows, [ $self->cleanup($manual, $option->name)
                    , $link
                    , $self->cleanup($manual, $default->value)
                    ];
    }

    $output->print("\n");
    $self->writeTable
     ( output => $output
     , header => ['Option', 'Defined in', 'Default']
     , rows   => \@rows
     , widths => [undef, 15, undef]
     );

    $self
}

#-------------------------------------------


sub showOptions(@)
{   my ($self, %args) = @_;

    my $options = $args{options} or confess;
    my $manual  = $args{manual}  or confess;

    foreach (@$options)
    {   my ($option, $default) = @$_;
        my $show
         = $manual->inherited($option) ? $args{show_inherited_options}
         :                               $args{show_described_options};

        my $action
         = $show eq 'USE'   ? 'showOptionUse'
         : $show eq 'EXPAND'? 'showOptionExpand'
         : croak "ERROR: illegal show option choice $show";

        $self->$action(%args, option => $option, default => $default);
    }
    $self;
}

#-------------------------------------------


sub showOptionUse(@) {shift}

#-------------------------------------------


sub showOptionExpand(@) {shift}

#-------------------------------------------


sub createInheritance($)
{   my ($self, $package) = @_;

    if($package->name ne $package->package)
    {   # This is extra code....
        my $from = $package->package;
        return "\n $package\n    contains extra code for\n    M<$from>\n";
    }

    my $output;
    my @supers  = $package->superClasses;

    if(my $realized = $package->realizes)
    {   $output .= "\n $package realizes a M<$realized>\n";
        @supers = $realized->superClasses if ref $realized;
    }

    if(my @extras = $package->extraCode)
    {   $output .= "\n $package has extra code in\n";
        $output .= "   M<$_>\n" foreach sort @extras;
    }

    foreach (@supers)
    {   $output .= "\n $package\n";
        $output .= $self->showSuperSupers($_);
    }

    if(my @subclasses = $package->subClasses)
    {   $output .= "\n $package is extended by\n";
        $output .= "   M<$_>\n" foreach sort @subclasses;
    }

    if(my @realized = $package->realizers)
    {   $output .= "\n $package is realized by\n";
        $output .= "   M<$_>\n" foreach sort @realized;
    }

    $output;
}

sub showSuperSupers($)
{   my ($self, $package) = @_;
    my $output = "   is a M<$package>\n";
    return $output
        unless ref $package;  # only the name of the package is known

    if(my $realizes = $package->realizes)
    {   $output .= $self->showSuperSupers($realizes);
        return $output;
    }

    my @supers = $package->superClasses or return $output;
    $output .= $self->showSuperSupers(shift @supers);

    foreach(@supers)
    {   $output .= "\n\n   $package also extends M<$_>\n";
        $output .= $self->showSuperSupers($_);
    }

    $output;
}

#-------------------------------------------


1;

