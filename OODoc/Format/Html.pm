
package OODoc::Format::Html;
use vars '$VERSION';
$VERSION = '0.04';
use base 'OODoc::Format';

use strict;
use warnings;

use Carp;
use IO::Scalar;
use IO::File;

use File::Spec;
use File::Find     'find';
use File::Basename qw/basename dirname/;
use File::Copy     'copy';
use POSIX          'strftime';

use Text::MagicTemplate;


#-------------------------------------------


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    my $html = delete $args->{html_root} || '/';
    $html    =~ s!/$!!;

    $self->{OFH_html} = $html;
    $self->{OFH_jump} = delete $args->{jump_script} || "$html/jump.cgi";
    $self->{OFH_meta} = delete $args->{html_meta_data};
    $self;
}

#-------------------------------------------


sub cleanupString($$)
{   my $self = shift;
    my $text = $self->cleanup(@_);
    $text =~ s!\</?p\>!!g;
    $text;
}

#-------------------------------------------


sub link($$;$)
{   my ($self, $manual, $object, $text) = @_;
    $text = $object->name unless defined $text;

    my $jump
      = $object->isa('OODoc::Manual') ? "$self->{OFH_html}/$object/index.html"
      :   $self->{OFH_jump}.'?'.$manual->name.'&'.$object->unique;

    qq[<a href="$jump" target="_top">$text</a>];
}

#-------------------------------------------


sub mark($$)
{   my ($self, $manual, $id) = @_;
    $self->{OFH_markers}->print("$id $manual $self->{OFH_filename}\n");
}

#-------------------------------------------


sub createManual($@)
{   my ($self, %args) = @_;
    my $verbose  = $args{verbose} || 0;
    my $manual   = $args{manual} or confess;
    my $options  = $args{format_options} || [];

    # Location for the manual page files.

    my $template = $args{template} || File::Spec->catdir('html', 'manual');
    my %template = $self->expandTemplate($template, $options);

    my $dest = File::Spec->catdir($self->workdir, "$manual");
    $self->mkdirhier($dest);

    # File to trace markers must be open.

    unless(defined $self->{OFH_markers})
    {   my $markers = File::Spec->catdir($self->workdir, 'markers');
        my $mark = IO::File->new($markers, 'w')
            or die "Cannot write markers to $markers: $!\n";
        $self->{OFH_markers} = $mark;
        $mark->print($self->{OFH_html}, "\n");
    }

    #
    # Process template
    #

    my $manifest = $self->manifest;
    while(my($raw, $options) = each %template)
    {   my $cooked = File::Spec->catfile($dest, basename $raw);

        print "$manual: $cooked\n" if $verbose > 2;
        $manifest->add($cooked);

        my $output  = IO::File->new($cooked, "w")
          or die "ERROR: cannot write html manual at $cooked: $!";

        $self->{OFH_filename} = basename $raw;

        $self->format
         ( manual   => $manual
         , output   => $output
         , template => $raw
         , @$options
         );
    }

    delete $self->{OFH_filename};
    $self;
}

#-------------------------------------------


sub createOtherPages(@)
{   my ($self, %args) = @_;
    
    my $verbose  = $args{verbose} || 0;

    #
    # Collect files to be processed
    #

    my $source   = $args{source};
    if(defined $source)
    {   croak "ERROR: html source directory $source does not exist.\n"
             unless -d $source;
    }
    else
    {   $source = File::Spec->catdir("html", "other");
        return $self unless -d $source;
    }

    my $process  = $args{process}  || qr/\.(s?html|cgi)$/;

    my $dest = $self->workdir;
    $self->mkdirhier($dest);

    my @sources;
    find( { no_chdir => 1
          , wanted   => sub { my $fn = $File::Find::name;
                              push @sources, $fn if -f $fn;
                            }
           }, $source
        );

    #
    # Process files, one after the other
    #

    my $manifest = $self->manifest;
    foreach my $raw (@sources)
    {   (my $cooked = $raw) =~ s/$source/$dest/;

        print "create $cooked\n" if $verbose > 2;
        $manifest->add($cooked);

        unless($raw =~ $process)
        {   copy($raw, $cooked)
               or die "ERROR: Copy from $raw to $cooked failed: $!\n";

            next;
        }

        $self->mkdirhier(dirname $cooked);
        my $output  = IO::File->new($cooked, "w")
            or die "ERROR: cannot write html other file at $cooked: $!";

        my $options = [];
        $self->format
         ( manual   => undef
         , output   => $output
         , template => $raw
         , @$options
         );
    }

    $self;
}

#-------------------------------------------

 
sub expandTemplate($$)
{   my $self     = shift;
    my $loc      = shift || confess;
    my $defaults = shift || [];

    my @result;
    if(ref $loc eq 'HASH')
    {   foreach my $n (keys %$loc)
        {   my %options = (@$defaults, @{$loc->{$n}});
            push @result, $self->expandTemplate($n, [ %options ])
        }
    }
    elsif(-d $loc)
    {   find( { no_chdir => 1,
                wanted   => sub { my $fn = $File::Find::name;
                                  push @result, $fn, $defaults
                                     if -f $fn;
                                }
              }, $loc
            );
    }
    elsif(-f $loc) { push @result, $loc, $defaults }
    else { croak "ERROR: cannot find template source $loc." }

    @result;
}

#-------------------------------------------


our %producers =
 ( a           => 'templateHref'
 , chapter     => 'templateChapter'
 , date        => 'templateDate'
 , index       => 'templateIndex'
 , inheritance => 'templateInheritance'
 , list        => 'templateList'
 , manual      => 'templateManual'
 , meta        => 'templateMeta'
 , name        => 'templateName'
 , project     => 'templateProject'
 , title       => 'templateTitle'
 , version     => 'templateVersion'
 );
   
sub format(@)
{   my ($self, %args) = @_;
    my $output    = delete $args{output};

    my %permitted;
    while(my ($tag, $method) = each %producers)
    {   $permitted{$tag} = sub { $self->$method(\@_, \%args) };
    }

    my $template  = Text::MagicTemplate->new
     ( { -markers   => 'HTML'
       , -behaviors => 'HTML'
       , -lookups   => \%permitted
       }
     );

    my $created = $template->output($args{template});
    $output->print($$created);
}

#-------------------------------------------

sub templateProject($$)
{   my ($self, $attr, $args) = @_;
    $self->project;
}

#-------------------------------------------


sub templateTitle($$)
{   my ($self, $attr, $args) = @_;

    my $manual = $args->{manual}
       or die "ERROR: not a manual, so no automatic title in $args->{template}\n";

    my $name   = $self->cleanupString($manual, $manual->name);
    $name =~ s/\<[^>]*\>//g;
    $name;
}

#-------------------------------------------


sub templateManual($$)
{   my ($self, $attr, $args) = @_;

    my $manual = $args->{manual}
       or confess "ERROR: not a manual, so no manual name for $args->{template}\n";

    $self->cleanupString($manual, $manual->name);
}

#-------------------------------------------

# The version is taken from the manual (which means that you may have
# a different version number per manual) when a manual is being formatted,
# and otherwise the project total version.

sub templateVersion($$)
{   my ($self, $attr, $args) = @_;
    my $manual  = $args->{manual};
    defined $manual ? $manual->version : $self->version;
}

#-------------------------------------------

sub templateDate($$)
{   my ($self, $attr, $args) = @_;
    strftime "%Y/%m/%d", localtime;
}

#-------------------------------------------


sub templateName($$)
{   my ($self, $attr, $args) = @_;

    my $manual = $args->{manual}
       or die "ERROR: not a manual, so no name for $args->{template}\n";

    my $chapter = $manual->chapter('NAME')
       or die "ERROR: cannot find chapter NAME in manual $manual";

    my $descr   = $chapter->description;

    return $1 if $descr =~ m/^\s*\S+\s*\-\s*(.*?)\s*$/;
   
    die "ERROR: chapter NAME in manual $manual has illegal shape";
}

#-------------------------------------------

our %path_lookup =
 ( front       => "index.html"
 , manuals     => "manuals/index.html"
 , methods     => "methods/index.html"
 , diagnostics => "diagnostics/index.html"
 , details     => "details/index.html"
 );

sub templateHref($$)
{   my ($self, $attr, $args) = @_;
    my ($capture, $flags) = @$attr;

    my ($to, $window) = split " ", $flags;
    my $path   = $path_lookup{$to} || warn "missing path for $to";

    qq[<a href="$self->{OFH_html}/$path" target="_top">];
}

#-------------------------------------------


sub templateMeta($$)
{   my ($self, $attr, $args) = @_;
    $self->{OFH_meta};
}

#-------------------------------------------


sub templateInheritance(@)
{   my ($self, $attr, $args) = @_;

    my $manual  = $args->{manual} or confess;
    my $output  = $self->cleanup($manual, $self->createInheritance($manual));
    for($output)
    {   s#<pre>\n*(.*)</pre>\n*#$1#s;            # over-eager cleanup
        s#^( +)#'&nbsp;' x length($1)#gme;
        s#$#<br />#gm;
    }
    $output;
}

#-------------------------------------------


sub templateChapter($$)
{   my ($self, $attr, $args) = @_;
    my ($contained, $attributes) = @$attr;
    my $name = $attributes =~ s/^\s*(\w+)\b// ? $1 : undef;

    croak "ERROR: chapter without name in template"
       unless defined $name;

    warn "WARNING: no meaning for container $contained in chapter block\n"
        if defined $contained && length $contained;

    my @attrs   = split " ", $attributes;

    my $manual  = $args->{manual} or confess;
    my $chapter = $manual->chapter($name) or return '';

    my $out     = '';
    $self->showChapter(%$args, chapter => $chapter,
       output => IO::Scalar->new(\$out), @attrs);

    $out;
}

#-------------------------------------------


sub templateIndex($$)
{   my ($self, $attr, $args) = @_;
    my ($contained, $attributes) = @$attr;
    my $group    = $attributes =~ s/^\s*(\w+)\b// ? $1 : undef;
    my %opts     = split " ", $attributes;

    die "ERROR: no group named as attribute for list\n"
       unless defined $group;

    warn "WARNING: no meaning for container $contained in list block\n"
        if defined $contained && length $contained;

    my $start  = $opts{starting_with} || $args->{starting_with} ||'ALL';
    my $types  = $opts{type}          || $args->{type}          ||'ALL';

    my $select = sub { @_ };
    unless($start eq 'ALL')
    {   $start =~ s/_/[\\W_]/g;
        my $regexp = qr/^$start/i;
        $select    = sub { grep { $_->name =~ $regexp } @_ };
    }
    unless($types eq 'ALL')
    {   my @take   = map { $_ eq 'method' ? '.*method' : $_ }
                         split /_/, $types;
        local $"   = ')|(';
        my $regexp = qr/^(@take)$/i;
        my $before = $select;
        $select    = sub { grep { $_->type =~ $regexp } $before->(@_) };
    }

    my $columns = $opts{table_columns} || $args->{table_columns} || 2;
    my @rows;

    if($group eq 'SUBROUTINES')
    {   my @subs;

        foreach my $manual ($self->manuals)
        {   foreach my $sub ($select->($manual->ownSubroutines))
            {   my $linksub = $self->link($manual, $sub, $sub->name);
                my $linkman = $self->link(undef, $manual, $manual->name);
                my $link    = "$linksub -- $linkman";
                push @subs, [ lc("$sub-$manual"), $link ];
            }
        }

        @rows = map { $_->[1] }
            sort { $a->[0] cmp $b->[0] } @subs;
    }
    elsif($group eq 'DIAGNOSTICS')
    {   foreach my $manual ($self->manuals)
        {   foreach my $sub ($manual->ownSubroutines)
            {   my @diags    = $select->($sub->diagnostics) or next;

                my $linksub  = $self->link($manual, $sub, $sub->name);
                my $linkman  = $self->link(undef, $manual, $manual->name);

                foreach my $diag (@diags)
                {   my $type = uc($diag->type);
                    push @rows, <<"DIAG";
$type: $diag<br />
&middot;&nbsp;$linksub in $linkman<br />
DIAG
                }
            }
        }

       @rows = sort @rows;
    }
    elsif($group eq 'DETAILS')
    {  foreach my $manual (sort $select->($self->manuals))
       {   my $details  = $manual->chapter("DETAILS") or next;
           my @sections = grep {not $manual->inherited($_)}
                              $details->sections;
           next unless @sections || length $details->description;

           my $sections = join "\n"
                             , map { "<li>".$self->link($manual, $_)."</li>" }
                                @sections;

           push @rows, $self->link($manual, $details, "Details in $manual")
                       . qq[\n<ul>\n$sections</ul>\n]
       }
    }
    elsif($group eq 'MANUALS')
    {  @rows = map { $self->link(undef, $_, $_->name) }
                 sort $select->($self->manuals);
    }
    else
    {  die "ERROR: unknown group $group as list attribute.\n";
    }

    push @rows, ('') x ($columns-1);
    my $rows   = int(@rows/$columns);

    my $output = qq[<tr>];
    while(@rows >= $columns)
    {   $output .= qq[<td valign="top">]
                . join( "<br />\n", splice(@rows, 0, $rows))
                .  qq[</td>\n];
    }
    $output   .= qq[</tr>\n];
    $output;
}

#-------------------------------------------


sub templateList($$)
{   my ($self, $attr, $args) = @_;
    my ($contained, $attributes) = @$attr;
    my $group    = $attributes =~ s/^\s*(\w+)\b// ? $1 : undef;
    my %opts     = split " ", $attributes;

    die "ERROR: no group named as attribute for index\n"
       unless defined $group;

    warn "WARNING: no meaning for container $contained in index block\n"
        if defined $contained && length $contained;

    my $show_sub = $opts{show_subroutines}||$args->{show_subroutines}||'LIST';
    my $types    = $opts{subroutine_types}||$args->{subroutine_types}||'ALL';
    my $manual   = $args->{manual} or confess;

    my $output   = '';

    my $selected = sub { @_ };
    unless($types eq 'ALL')
    {   my @take   = map { $_ eq 'method' ? '.*method' : $_ }
                         split /_/, $types;
        local $"   = ')|(';
        my $regexp = qr/^(@take)$/;
        $selected  = sub { grep { $_->type =~ $regexp } @_ };
    }

    my $sorted     = sub { sort {$a->name cmp $b->name} @_ };

    if($group eq 'ALL')
    {   my @subs   = $sorted->($selected->($manual->subroutines));
        if(!@subs || $show_sub eq 'NO') { ; }
        elsif($show_sub eq 'COUNT')     { $output .= @subs }
        else
        {   $output .= $self->indexListSubroutines($manual,@subs);
        }
    }
    else  # any chapter
    {   my $chapter  = $manual->chapter($group) or return;
        my $show_sec = $opts{show_sections} ||$args->{show_sections} ||'LINK';
        my @sections = $show_sec eq 'NO' ? () : $chapter->sections;

        my @subs = $sorted->($selected->( @sections
                                        ? $chapter->subroutines
                                        : $chapter->all('subroutines')
                                        )
                             );

        $output  .= $self->link($manual, $chapter, $chapter->niceName); 
        my $count = @subs && $show_sub eq 'COUNT' ? ' ('.@subs.')' : '';

        if($show_sec eq 'NO') { $output .= qq[$count<br />\n] }
        elsif($show_sec eq 'LINK' || $show_sec eq 'NAME')
        {   $output .= qq[<br />\n<ul>\n];
            if(!@subs) {;}
            elsif($show_sec eq 'LINK')
            {   my $link = $self->link($manual, $chapter, 'unsorted');
                $output .= qq[<li>$link$count\n];
            }
            elsif($show_sec eq 'NAME')
            {   $output .= qq[<li>unsorted$count\n];
            }

            $output .= qq[<br />\n] . $self->indexListSubroutines($manual,@subs)
                if @subs && $show_sub eq 'LIST';
        }
        else
        {   confess "ERROR: illegal value to show_sections: $show_sec\n";
        }
     
        # All sections within the chapter (if show_sec is enabled)

        foreach my $section (@sections)
        {   my @subs  = $sorted->($selected->($section->all('subroutines')));

            my $count = $show_sub eq 'COUNT' && @subs ? ' ('.@subs.')' : '';
            if($show_sec eq 'LINK')
            {   my $link = $self->link($manual, $section, $section->niceName);
                $output .= qq[<li>$link$count\n];
            }
            else
            {   $output .= qq[<li>$section$count\n];
            }

            $output .= qq[<br />\n] . $self->indexListSubroutines($manual,@subs)
                if $show_sub eq 'LIST' && @subs;

            $output .= qq[</li>\n];
        }

        $output .= qq[</ul>\n]
             if $show_sec eq 'LINK' || $show_sec eq 'NAME';
    }

    $output;
}

#-------------------------------------------

sub indexListSubroutines(@)
{   my $self   = shift;
    my $manual = shift;
    
    join ",\n    "
       , map { $self->link($manual, $_, $_) }
            @_;
}

#-------------------------------------------

sub showStructureExpand(@)
{   my ($self, %args) = @_;

    my $examples = $args{show_chapter_examples} || 'EXPAND';
    my $text     = $args{structure} or confess;

    my $name     = $text->name;
    my $level    = $text->level;
    my $output   = $args{output}  or confess;
    my $manual   = $args{manual}  or confess;

    my $descr   = $self->cleanup($manual, $text->description);
    (my $id     = $text->name) =~ s/\W+/_/g;
    my $unique  = $text->unique;

    $output->print(
        qq[\n<h$level id="$id"><a name="$unique">$name</a></h$level>\n$descr]
                  );
    $self->mark($manual, $unique);

    $self->showSubroutines(%args, subroutines => [$text->subroutines]);
    $self->showExamples(%args, examples => [$text->examples])
         if $examples eq 'EXPAND';

    return $self;
}

#-------------------------------------------

sub showStructureRefer(@)
{   my ($self, %args) = @_;

    my $text     = $args{structure} or confess;

    my $name     = $text->name;
    my $level    = $text->level;
    my $output   = $args{output}  or confess;
    my $manual   = $args{manual}  or confess;

    my $link     = $self->link($manual, $text);
    $output->print(
       qq[\n<h$level id="$name"><a href="$link">$name</a><h$level>\n]);
    $self;
}

#-------------------------------------------

sub chapterDiagnostics(@)
{   my ($self, %args) = @_;

    my $manual  = $args{manual} or confess;
    my $diags   = $manual->chapter('DIAGNOSTICS');

    my @diags   = map {$_->diagnostics} $manual->subroutines;
    $diags      = OODoc::Text::Chapter->new(name => 'DIAGNOSTICS')
        if !$diags && @diags;

    return unless $diags;

    $self->showChapter(chapter => $diags, %args)
        if defined $diags;

    $self->showDiagnostics(%args, diagnostics => \@diags);
    $self;
}

#-------------------------------------------

sub showExamples(@)
{   my ($self, %args) = @_;
    my $examples = $args{examples} or confess;
    return unless @$examples;

    my $manual    = $args{manual}  or confess;
    my $output    = $args{output}  or confess;

    $output->print( qq[<dl class="example">\n] );

    foreach my $example (@$examples)
    {   my $name   = $example->name;
        my $descr  = $self->cleanup($manual, $example->description);
        my $unique = $example->unique;
        $output->print( <<EXAMPLE );
<dt>&raquo;&nbsp;<a name="$unique">Example</a>: $name</dt>
<dd>$descr</dd>
EXAMPLE

         $self->mark($manual, $unique);
    }
    $output->print( qq[</dl>\n] );

    $self;
}

#-------------------------------------------

sub showDiagnostics(@)
{   my ($self, %args) = @_;
    my $diagnostics = $args{diagnostics} or confess;
    return unless @$diagnostics;

    my $manual    = $args{manual}  or confess;
    my $output    = $args{output}  or confess;

    $output->print( qq[<dl class="diagnostics">\n] );

    foreach my $diag (sort @$diagnostics)
    {   my $name    = $diag->name;
        my $type    = $diag->type;
        my $text    = $self->cleanup($manual, $diag->description);
        my $unique  = $diag->unique;

        $output->print( <<DIAG );
<dt class="type">&raquo;&nbsp;$type: <a name="$unique">$name</a></dt>
<dd>$text</dd>
DIAG

         $self->mark($manual, $unique);
    }

    $output->print( qq[</dl>\n] );
    $self;
}


sub showSubroutine(@)
{   my $self = shift;
    my %args   = @_;
    my $output = $args{output}     or confess;
    my $sub    = $args{subroutine} or confess;
    my $type   = $sub->type;
    my $name   = $sub->name;

    $self->SUPER::showSubroutine(@_);

    $output->print( qq[</dd>\n</dl>\n</div>\n] );
    $self;
}

#-------------------------------------------

sub showSubroutineUse(@)
{   my ($self, %args) = @_;
    my $subroutine = $args{subroutine} or confess;
    my $manual     = $args{manual}     or confess;
    my $output     = $args{output}     or confess;

    my $type       = $subroutine->type;
    my $name       = $self->cleanupString($manual, $subroutine->name);
    my $paramlist  = $self->cleanupString($manual, $subroutine->parameters);
    my $unique     = $subroutine->unique;

    my $class      = $manual->package;

    my $call       = qq[<b><a name="$unique">$name</a></b>];
    $call         .= "($paramlist)" if length $paramlist;
    $self->mark($manual, $unique);

    my $use
      = $type eq 'i_method' ? qq[\$obj-&gt;$call]
      : $type eq 'c_method' ? qq[\$class-&gt;$call]
      : $type eq 'ci_method'? qq[\$obj-&gt;$call<br />\$class-&gt;$call]
      : $type eq 'overload' ? qq[overload: $call]
      : $type eq 'tie'      ? $call
      :                       '';

    warn "WARNING: unknown subroutine type $type for $name in $manual"
        unless length $use;

    $output->print( <<SUBROUTINE );
<div class="$type" id="$name">
<dl>
<dt class="sub_use">$use</dt>
<dd class="sub_body">
SUBROUTINE

    if($manual->inherited($subroutine))
    {   my $defd    = $subroutine->manual;
        my $sublink = $self->link($defd, $subroutine, $name);
        my $manlink = $self->link($manual, $defd);
        $output->print( qq[See $sublink in $manlink.<br />\n] );
    }

    $self;
}

#-------------------------------------------

sub showSubsIndex(@)
{   my ($self, %args) = @_;
    my $output     = $args{output}     or confess;
    $output->print("Subs index here\n");
}

#-------------------------------------------

sub showSubroutineName(@)
{   my ($self, %args) = @_;
    my $subroutine = $args{subroutine} or confess;
    my $manual     = $args{manual}     or confess;
    my $output     = $args{output}     or confess;
    my $name       = $subroutine->name;

    my $url
     = $manual->inherited($subroutine)
     ? "M<".$subroutine->manual."::$name>"
     : "M<$name>";

    $output->print
     ( $self->cleanupString($manual, $url)
     , ($args{last} ? ".\n" : ",\n")
     );
}

#-------------------------------------------

sub showOptions(@)
{   my $self   = shift;
    my %args   = @_;
    my $output = $args{output} or confess;
    $output->print( qq[<dl class="options">\n] );

    $self->SUPER::showOptions(@_);

    $output->print( qq[</dl>\n] );
    $self;
}

#-------------------------------------------

sub showOptionUse(@)
{   my ($self, %args) = @_;
    my $output = $args{output} or confess;
    my $option = $args{option} or confess;
    my $manual = $args{manual} or confess;

    my $params = $self->cleanupString($manual, $option->parameters);
    $params    =~ s/\s+$//;
    $params    =~ s/^\s+//;
    $params    = qq[ =&gt; <span class="params">$params</span>]
        if length $params;
 
    my $use    = qq[<span class="option">$option</span>];
    $output->print( qq[<dt class="option_use">$use$params</dt>\n] );
    $self;
}

#-------------------------------------------

sub showOptionExpand(@)
{   my ($self, %args) = @_;
    my $output = $args{output} or confess;
    my $option = $args{option} or confess;
    my $manual = $args{manual}  or confess;

    $self->showOptionUse(%args);

    my $where = $option->findDescriptionObject or return $self;
    my $descr = $self->cleanup($manual, $where->description);

    $output->print( qq[<dd>$descr</dd>\n] )
        if length $descr;

    $self;
}

#-------------------------------------------


sub writeTable($@)
{   my ($self, %args) = @_;

    my $rows   = $args{rows}   or confess;
    return unless @$rows;

    my $head   = $args{header} or confess;
    my $output = $args{output} or confess;

    $output->print( qq[<table cellspacing="3" cellpadding="0">\n] );

    local $"   = qq[</th>    <th align="left">];
    $output->print( qq[<tr><th align="left">@$head</th></tr>\n] );

    local $"   = qq[</td>    <td valign="top">];
    $output->print( qq[<tr><td align="left">@$_</td></tr>\n] )
        foreach @$rows;

    $output->print( qq[</table>\n] );
    $self;
}

#-------------------------------------------

sub showSubroutineDescription(@)
{   my ($self, %args) = @_;
    my $manual  = $args{manual}                   or confess;
    my $subroutine = $args{subroutine}            or confess;

    my $text    = $self->cleanup($manual, $subroutine->description);
    return $self unless length $text;

    my $output  = $args{output}                   or confess;
    $output->print($text);

    my $extends = $self->extends                  or return $self;
    my $refer   = $extends->findDescriptionObject or return $self;

    $output->print("<br />\n");
    $self->showSubroutineDescriptionRefer(%args, subroutine => $refer);
}

#-------------------------------------------

sub showSubroutineDescriptionRefer(@)
{   my ($self, %args) = @_;
    my $manual  = $args{manual}                   or confess;
    my $subroutine = $args{subroutine}            or confess;
    my $output  = $args{output}                   or confess;
    $output->print("\nSee ", $self->link($manual, $subroutine), "\n");
}

#-------------------------------------------


1;
