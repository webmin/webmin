package Text::ASCIITable;
# by Håkon Nessjøen <lunatic@cpan.org>

@ISA=qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw();
$VERSION = '0.22';
use Exporter;
use strict;
use Carp;
use Text::ASCIITable::Wrap qw{ wrap };
use overload '@{}' => 'addrow_overload', '""' => 'drawit';
use utf8;
use List::Util qw(reduce max sum);

=encoding utf8

=head1 NAME

Text::ASCIITable - Create a nice formatted table using ASCII characters.

=head1 SHORT DESCRIPTION

Pretty nifty if you want to output dynamic text to your console or other
fixed-size-font displays, and at the same time it will display it in a
nice human-readable, or "cool" way.

=head1 SYNOPSIS

  use Text::ASCIITable;
  $t = Text::ASCIITable->new({ headingText => 'Basket' });
  
  $t->setCols('Id','Name','Price');
  $t->addRow(1,'Dummy product 1',24.4);
  $t->addRow(2,'Dummy product 2',21.2);
  $t->addRow(3,'Dummy product 3',12.3);
  $t->addRowLine();
  $t->addRow('','Total',57.9);
  print $t;
  
  # Result:
  .------------------------------.
  |            Basket            |
  +----+-----------------+-------+
  | Id | Name            | Price |
  +----+-----------------+-------+
  |  1 | Dummy product 1 |  24.4 |
  |  2 | Dummy product 2 |  21.2 |
  |  3 | Dummy product 3 |  12.3 |
  +----+-----------------+-------+
  |    | Total           |  57.9 |
  '----+-----------------+-------'

=head1 FUNCTIONS

=head2 new(options)

Initialize a new table. You can specify output-options. For more options, check out the usage for setOptions()

  Usage:
  $t = Text::ASCIITable->new();

  Or with options:
  $t = Text::ASCIITable->new({ hide_Lastline => 1, reportErrors => 0});

=cut

sub new {
  my $self = {
		tbl_cols => [],
		tbl_rows => [],
		tbl_cuts => [],
		tbl_align => {},
		tbl_lines => {},

		des_top       => ['.','.','-','-'],
		des_middle    => ['+','+','-','+'],
		des_bottom    => ["'","'",'-','+'],
		des_rowline   => ['+','+','-','+'],

		des_toprow    => ['|','|','|'],
		des_middlerow => ['|','|','|'],

		cache_width   => {},

		options => $_[1] || { }
  };

  $self->{options}{reportErrors} = defined($self->{options}{reportErrors}) ? $self->{options}{reportErrors} : 1; # default setting
  $self->{options}{alignHeadRow} = $self->{options}{alignHeadRow} || 'auto'; # default setting
  $self->{options}{undef_as} = $self->{options}{undef_as} || ''; # default setting
  $self->{options}{chaining} = $self->{options}{chaining} || 0; # default setting

  bless $self;

  return $self;
}

=head2 setCols(@cols)

Define the columns for the table(compare with <TH> in HTML). For example C<setCols(['Id','Nick','Name'])>.
B<Note> that you cannot add Cols after you have added a row. Multiline columnnames are allowed.

=cut

sub setCols {
  my $self = shift;
  do { $self->reperror("setCols needs an array"); return $self->{options}{chaining} ? $self : 1; } unless defined($_[0]);
  @_ = @{$_[0]} if (ref($_[0]) eq 'ARRAY');
  do { $self->reperror("setCols needs an array"); return $self->{options}{chaining} ? $self : 1; } unless scalar(@_) != 0;
  do { $self->reperror("Cannot edit cols at this state"); return $self->{options}{chaining} ? $self : 1; } unless scalar(@{$self->{tbl_rows}}) == 0;

  my @lines = map { [ split(/\n/,$_) ] } @_;

  # Multiline support
  my $max=0;
  my @out;
  grep {$max = scalar(@{$_}) if scalar(@{$_}) > $max} @lines;
  foreach my $num (0..($max-1)) {
    my @tmp = map defined $$_[$num] && $$_[$num], @lines;
    push @out, \@tmp;
  }

  @{$self->{tbl_cols}} = @_;
	@{$self->{tbl_multilinecols}} = @out if ($max);
  $self->{tbl_colsismultiline} = $max;

  return $self->{options}{chaining} ? $self : undef;
}

=head2 addRow(@collist)

Adds one row to the table. This must be an array of strings. If you defined 3 columns. This array must
have 3 items in it. And so on. Should be self explanatory. The strings can contain newlines.

  Note: It does not require argument to be an array, thus;
  $t->addRow(['id','name']) and $t->addRow('id','name') does the same thing.

This module is also overloaded to accept push. To construct a table with the use of overloading you might do the following:

  $t = Text::ASCIITable->new();
  $t->setCols('one','two','three','four');
  push @$t, ( "one\ntwo" ) x 4; # Replaces $t->addrow();
  print $t;                     # Replaces print $t->draw();
  
  Which would construct:
   .-----+-----+-------+------.
   | one | two | three | four |
   |=----+-----+-------+-----=|
   | one | one | one   | one  |  # Note that theese two lines
   | two | two | two   | two  |  # with text are one singe row.
   '-----+-----+-------+------'

There is also possible to give this function an array of arrayrefs and hence support the output from
DBI::selectall_arrayref($sql) without changes.

  Example of multiple-rows pushing:
  $t->addRow([
    [ 1, 2, 3 ],
    [ 4, 5, 6 ],
    [ 7, 8, 9 ],
  ]);

=cut

sub addRow {
  my $self = shift;
  @_ = @{$_[0]} if (ref($_[0]) eq 'ARRAY');
  do { $self->reperror("Received too many columns"); return $self->{options}{chaining} ? $self : 1; } if scalar(@_) > scalar(@{$self->{tbl_cols}}) && ref($_[0]) ne 'ARRAY';
  my (@in,@out,@lines,$max);

	if (scalar(@_) > 0 && ref($_[0]) eq 'ARRAY') {
		foreach my $row (@_) {
			$self->addRow($row);
		}
		return $self->{options}{chaining} ? $self : undef;
	}

  # Fill out row, if columns are missing (requested) Mar 21  2004 by a anonymous person
  while (scalar(@_) < scalar(@{$self->{tbl_cols}})) {
    push @_, ' ';
  }

  # Word wrapping & undef-replacing
  foreach my $c (0..$#_) {
    $_[$c] = $self->{options}{undef_as} unless defined $_[$c]; # requested by david@landgren.net/dland@cpan.org - https://rt.cpan.org/NoAuth/Bugs.html?Dist=Text-ASCIITable
    my $colname = $self->{tbl_cols}[$c];
    my $width = $self->{tbl_width}{$colname} || 0;
    if ($width > 0) {
      $in[$c] = wrap($_[$c],$width);
    } else {
      $in[$c] = $_[$c];
    }
  }

  # Multiline support:
  @lines = map { [ split /\n/ ] } @in;
  $max = max map {scalar @$_} @lines;
  foreach my $num (0..($max-1)) {
    my @tmp = map { defined(@{$_}[$num]) && $self->count(@{$_}[$num]) ? @{$_}[$num] : '' } @lines;
    push @out, [ @tmp ];
  }

  # Add row(s)
  push @{$self->{tbl_rows}}, @out;

  # Rowlinesupport:
  $self->{tbl_rowline}{scalar(@{$self->{tbl_rows}})} = 1;

  return $self->{options}{chaining} ? $self : undef;
}

sub addrow_overload {
   my $self = shift;
   my @arr;
   tie @arr, $self;
   return \@arr;
}

=head2 addRowLine([$row])

Will add a line after the current row. As an argument, you may specify after which row you want a line (first row is 1)
or an array of row numbers. (HINT: If you want a line after every row, read about the drawRowLine option in setOptions())

Example without arguments:
  $t->addRow('one','two','three');
  $t->addRowLine();
  $t->addRow('one','two','three');

Example with argument:
  $t->addRow('one','two','three');
  $t->addRow('one','two','three');
  $t->addRow('one','two','three');
  $t->addRow('one','two','three');
  $t->addRowLine(1); # or multiple: $t->addRowLine([2,3]);

=cut

sub addRowLine {
  my ($self,$row) = @_;
  do { $self->reperror("rows not added yet"); return $self->{options}{chaining} ? $self : 1; } unless scalar(@{$self->{tbl_rows}}) > 0;

	if (defined($row) && ref($row) eq 'ARRAY') {
		foreach (@$row) {
			$_=int($_);
			$self->{tbl_lines}{$_} = 1;
		}
	}
	elsif (defined($row)) {
		$row = int($row);
		do { $self->reperror("$row is higher than number of rows added"); return $self->{options}{chaining} ? $self : 1; } if ($row < 0 || $row > scalar(@{$self->{tbl_rows}}));
		$self->{tbl_lines}{$row} = 1;
	} else {
		$self->{tbl_lines}{scalar(@{$self->{tbl_rows}})} = 1;
	}

	return $self->{options}{chaining} ? $self : undef;
}

# backwardscompatibility, deprecated
sub alignColRight {
  my ($self,$col) = @_;
  do { $self->reperror("alignColRight is missing parameter(s)"); return $self->{options}{chaining} ? $self : 1; } unless defined($col);
  return $self->alignCol($col,'right');
}

=head2 alignCol($col,$direction) or alignCol({col1 => direction1, col2 => direction2, ... })

Given a columnname, it aligns all data to the given direction in the table. This looks nice on numerical displays
in a column. The column names in the table will be unaffected by the alignment. Possible directions is: left,
center, right, justify, auto or your own subroutine. (Hint: Using auto(default), aligns numbers right and text left) 

=cut

sub alignCol {
  my ($self,$col,$direction) = @_;
  do { $self->reperror("alignCol is missing parameter(s)"); return $self->{options}{chaining} ? $self : 1; } unless defined($col) && defined($direction) || (defined($col) && ref($col) eq 'HASH');
  do { $self->reperror("Could not find '$col' in columnlist"); return $self->{options}{chaining} ? $self : 1; } unless defined(&find($col,$self->{tbl_cols})) || (defined($col) && ref($col) eq 'HASH');

  if (ref($col) eq 'HASH') {
    for (keys %{$col}) {
      do { $self->reperror("Could not find '$_' in columnlist"); return $self->{options}{chaining} ? $self : 1; } unless defined(&find($_,$self->{tbl_cols}));
      $self->{tbl_align}{$_} = $col->{$_};
    }
  } else {
    $self->{tbl_align}{$col} = $direction;
  }
  return $self->{options}{chaining} ? $self : undef;
}

=head2 alignColName($col,$direction)

Given a columnname, it aligns the columnname in the row explaining columnnames, to the given direction. (auto,left,right,center,justify
or a subroutine) (Hint: Overrides the 'alignHeadRow' option for the specified column.)

=cut

sub alignColName {
  my ($self,$col,$direction) = @_;
  do { $self->reperror("alignColName is missing parameter(s)"); return $self->{options}{chaining} ? $self : 1; } unless defined($col) && defined($direction);
  do { $self->reperror("Could not find '$col' in columnlist"); return $self->{options}{chaining} ? $self : 1; } unless defined(&find($col,$self->{tbl_cols}));

  $self->{tbl_colalign}{$col} = $direction;
  return $self->{options}{chaining} ? $self : undef;
}

=head2 setColWidth($col,$width,$strict)

Wordwrapping/strict size. Set a max-width(in chars) for a column.
If last parameter is 1, the column will be set to the specified width, even if no text is that long.

 Usage:
  $t->setColWidth('Description',30);

=cut

sub setColWidth {
  my ($self,$col,$width,$strict) = @_;
  do { $self->reperror("setColWidth is missing parameter(s)"); return $self->{options}{chaining} ? $self : 1; } unless defined($col) && defined($width);
  do { $self->reperror("Could not find '$col' in columnlist"); return $self->{options}{chaining} ? $self : 1; } unless defined(&find($col,$self->{tbl_cols}));
  do { $self->reperror("Cannot change width at this state"); return $self->{options}{chaining} ? $self : 1; } unless scalar(@{$self->{tbl_rows}}) == 0;

  $self->{tbl_width}{$col} = int($width);
  $self->{tbl_width_strict}{$col} = $strict ? 1 : 0;

  return $self->{options}{chaining} ? $self : undef;
}

sub headingWidth {
	my $self = shift;
  my $title = $self->{options}{headingText};
  return max map {$self->count($_)} split /\r?\n/, $self->{options}{headingText};
}

# drawing etc, below
sub getColWidth {
  my ($self,$colname) = @_;
  $self->reperror("Could not find '$colname' in columnlist") unless defined find($colname, $self->{tbl_cols});

  return $self->{cache_width}{$colname};
}

# Width-calculating functions rewritten for more speed by Alexey Sheynuk <asheynuk@iponweb.net>
# Thanks :)
sub calculateColWidths {
  my ($self) = @_;
  $self->{cache_width} = undef;
  my $cols = $self->{tbl_cols};
  foreach my $c (0..$#{$cols}) {
    my $colname = $cols->[$c];
    if (defined($self->{tbl_width_strict}{$colname}) && ($self->{tbl_width_strict}{$colname} == 1) && int($self->{tbl_width}{$colname}) > 0) {
      # maxsize plus the spaces on each side
      $self->{cache_width}{$colname} = $self->{tbl_width}{$colname} + 2;
    } else {
      my $colwidth = max((map {$self->count($_)} split(/\n/,$colname)), (map {$self->count($_->[$c])} @{$self->{tbl_rows}}));
      $self->{cache_width}{$colname} = $colwidth + 2;
    }
  }
  $self->addExtraHeadingWidth;
}

sub addExtraHeadingWidth {
  my ($self) = @_;
  return unless defined $self->{options}{headingText};
  my $tablewidth = -3 + sum map {$_ + 1} values %{$self->{cache_width}};
  my $headingwidth = $self->headingWidth();
  if ($headingwidth > $tablewidth) {
    my $extra = $headingwidth - $tablewidth;
    my $cols = scalar(@{$self->{tbl_cols}});
    my $extra_for_all = int($extra/$cols);
    my $extrasome = $extra % $cols;
    my $antall = 0;
    foreach my $col (@{$self->{tbl_cols}}) {
      my $extrawidth = $extra_for_all;
      if ($antall < $extrasome) {
        $antall++;
        $extrawidth++;
      }
      $self->{cache_width}{$col} += $extrawidth;
    }
  }
}

=head2 getTableWidth()

If you need to know how wide your table will be before you draw it. Use this function.

=cut

sub getTableWidth {
  my $self = shift;
  my $totalsize = 1;
  if (!defined($self->{cache_TableWidth})) {
    $self->calculateColWidths;
    grep {$totalsize += $self->getColWidth($_,undef) + 1} @{$self->{tbl_cols}};
    $self->{cache_TableWidth} = $totalsize;
  }
  return $self->{cache_TableWidth};
}

sub drawLine {
  my ($self,$start,$stop,$line,$delim) = @_;
  do { $self->reperror("Missing reqired parameters"); return 1; } unless defined($stop);
  $line = defined($line) ? $line : '-'; 
  $delim = defined($delim) ? $delim : '+'; 

  my $contents;

  $contents = $start;

  for (my $i=0;$i < scalar(@{$self->{tbl_cols}});$i++) {
    my $offset = 0;
    $offset = $self->count($start) - 1 if ($i == 0);
    $offset = $self->count($stop) - 1 if ($i == scalar(@{$self->{tbl_cols}}) -1);

    $contents .= $line x ($self->getColWidth(@{$self->{tbl_cols}}[$i]) - $offset);

    $contents .= $delim if ($i != scalar(@{$self->{tbl_cols}}) - 1);
  }
  return $contents.$stop."\n";
}

=head2 setOptions(name,value) or setOptions({ option1 => value1, option2 => value2, ... })

Use this to set options like: hide_FirstLine,reportErrors, etc.

  Usage:
  $t->setOptions('hide_HeadLine',1);
  
  Or set more than one option on the fly:
  $t->setOptions({ hide_HeadLine => 1, hide_HeadRow => 1 });

B<Possible Options>

=over 4

=item hide_HeadRow

Hides output of the columnlisting. Together with hide_HeadLine, this makes a table only show the rows. (However, even though
the column-names will not be shown, they will affect the output if they have for example ridiculoustly long
names, and the rows contains small amount of info. You would end up with a lot of whitespace)

=item reportErrors

Set to 0 to disable error reporting. Though if a function encounters an error, it will still return the value 1, to
tell you that things didn't go exactly as they should.

=item allowHTML

If you are going to use Text::ASCIITable to be shown on HTML pages, you should set this option to 1 when you are going
to use HTML tags to for example color the text inside the rows, and you want the browser to handle the table correct.

=item allowANSI

If you use ANSI codes like <ESC>[1mHi this is bold<ESC>[m or similar. This option will make the table to be
displayed correct when showed in a ANSI compliant terminal. Set this to 1 to enable. There is an example of ANSI support
in this package, named ansi-example.pl.

=item alignHeadRow

Set wich direction the Column-names(in the headrow) are supposed to point. Must be left, right, center, justify, auto or a user-defined subroutine.

=item hide_FirstLine, hide_HeadLine, hide_LastLine

Speaks for it self?

=item drawRowLine

Set this to 1 to print a line between each row. You can also define the outputstyle
of this line in the draw() function.

=item headingText

Add a heading above the columnnames/rows wich uses the whole width of the table to output
a heading/title to the table. The heading-part of the table is automatically shown when
the headingText option contains text. B<Note:> If this text is so long that it makes the
table wider, it will not hesitate to change width of columns that have "strict width".

It supports multiline, and with Text::ASCIITable::Wrap you may wrap your text before entering
it, to prevent the title from expanding the table. Internal wrapping-support for headingText
might come in the future.

=item headingAlign

Align the heading(as mentioned above) to left, right, center, auto or using a subroutine.

=item headingStartChar, headingStopChar

Choose the startingchar and endingchar of the row where the title is. The default is
'|' on both. If you didn't understand this, try reading about the draw() function.

=item cb_count

Set the callback subroutine to use when counting characters inside the table. This is useful
to make support for having characters or codes inside the table that are not shown on the
screen to the user, so the table should not count these characters. This could be for example
HTML tags, or ANSI codes. Though those two examples are alredy supported internally with the
allowHTML and allowANSI, options. This option expects a CODE reference. (\&callback_function)

=item undef_as

Sets the replacing string that replaces an undef value sent to addRow() (or even the overloaded
push version of addRow()). The default value is an empty string ''. An example of use would be 
to set it to '(undef)', to show that the input really was undefined.


=item chaining

Set this to 1 to support chainging of methods. The default is 0, where the methods return 1 if
they come upon an error as mentioned in the reportErrors option description.

  Usage example:
  print Text::ASCIITable->new({ chaining => 1 })
    ->setCols('One','Two','Three')
    ->addRow([
      [ 1, 2, 3 ],
      [ 4, 5, 6 ],
      [ 7, 8, 9 ],
      ])
    ->draw();

Note that ->draw() can be omitted, since Text::ASCIITable is overloaded to print the table by default.

=back

=cut

sub setOptions {
  my ($self,$name,$value) = @_;
  my $old;
  if (ref($name) eq 'HASH') {
    for (keys %{$name}) {
      $self->{options}{$_} = $name->{$_};
    }
  } else {
    $old = $self->{options}{$name} || undef;
    $self->{options}{$name} = $value;
  }
  return $old;
}

# Thanks to Khemir Nadim ibn Hamouda <nadim@khemir.net>
# Original code from Spreadsheet::Perl::ASCIITable
sub prepareParts {
  my ($self)=@_;
  my $running_width = 1 ;

  $self->{tbl_cuts} = [];
  foreach my $column (@{$self->{tbl_cols}}) {
    my $column_width = $self->getColWidth($column,undef);
    if ($running_width  + $column_width >= $self->{options}{outputWidth}) {
      push @{$self->{tbl_cuts}}, $running_width;
      $running_width = $column_width + 2;
    } else {
      $running_width += $column_width + 1 ;
    }
  }
  push @{$self->{tbl_cuts}}, $self->getTableWidth() ;
}

sub pageCount {
  my $self = shift;
  do { $self->reperror("Table has no max output-width set"); return 1; } unless defined($self->{options}{outputWidth});

  return 1 if ($self->getTableWidth() < $self->{options}{outputWidth});
  $self->prepareParts() if (scalar(@{$self->{tbl_cuts}}) < 1);

  return scalar(@{$self->{tbl_cuts}});
}

sub drawSingleColumnRow {
  my ($self,$text,$start,$stop,$align,$opt) = @_;
  do { $self->reperror("Missing reqired parameters"); return 1; } unless defined($text);

  my $contents = $start;
  my $width = 0;
  my $tablewidth = $self->getTableWidth();
  # ok this is a bad shortcut, but 'till i get up with a better one, I use this.
  if (($tablewidth - 4) < $self->count($text) && $opt eq 'title') {
    $width = $self->count($text);
  }
  else {
    $width = $tablewidth - 4;
  }
  $contents .= ' '.$self->align(
                       $text,
                       $align || 'left',
                       $width,
                       ($self->{options}{allowHTML} || $self->{options}{allowANSI} || $self->{options}{cb_count} ?0:1)
                   ).' ';
  return $contents.$stop."\n";
}

sub drawRow {
  my ($self,$row,$isheader,$start,$stop,$delim) = @_;
  do { $self->reperror("Missing reqired parameters"); return 1; } unless defined($row);
  $isheader = $isheader || 0;
  $delim = $delim || '|';

  my $contents = $start;
  for (my $i=0;$i<scalar(@{$row});$i++) {
    my $colwidth = $self->getColWidth(@{$self->{tbl_cols}}[$i]);
    my $text = @{$row}[$i];

    if ($isheader != 1 && defined($self->{tbl_align}{@{$self->{tbl_cols}}[$i]})) {
      $contents .= ' '.$self->align(
                         $text,
                         $self->{tbl_align}{@{$self->{tbl_cols}}[$i]} || 'auto',
                         $colwidth-2,
                         ($self->{options}{allowHTML} || $self->{options}{allowANSI} || $self->{options}{cb_count}?0:1)
                       ).' ';
    } elsif ($isheader == 1) {

      $contents .= ' '.$self->align(
                         $text,
                         $self->{tbl_colalign}{@{$self->{tbl_cols}}[$i]} || $self->{options}{alignHeadRow} || 'left',
                         $colwidth-2,
                         ($self->{options}{allowHTML} || $self->{options}{allowANSI} || $self->{options}{cb_count}?0:1)
                       ).' ';
    } else {
      $contents .= ' '.$self->align(
                         $text,
                         'auto',
                         $colwidth-2,
                         ($self->{options}{allowHTML} || $self->{options}{allowANSI} || $self->{options}{cb_count}?0:1)
                       ).' ';
    }
    $contents .= $delim if ($i != scalar(@{$row}) - 1);
  }
  return $contents.$stop."\n";
}

=head2 draw([@topdesign,@toprow,@middle,@middlerow,@bottom,@rowline])

All the arrays containing the layout is optional. If you want to make your own "design" to the table, you
can do that by giving this method these arrays containing information about which characters to use
where.

B<Custom tables>

The draw method takes C<6> arrays of strings to define the layout. The first, third, fifth and sixth is B<LINE>
layout and the second and fourth is B<ROW> layout. The C<fourth> parameter is repeated for each row in the table.
The sixth parameter is only used if drawRowLine is enabled.

 $t->draw(<LINE>,<ROW>,<LINE>,<ROW>,<LINE>,[<ROWLINE>])

=over 4

=item LINE

Takes an array of C<4> strings. For example C<['|','|','-','+']>

=over 4

=item *

LEFT - Defines the left chars. May be more than one char.

=item *

RIGHT - Defines the right chars. May be more then one char.

=item *

LINE - Defines the char used for the line. B<Must be only one char>.

=item *

DELIMETER - Defines the char used for the delimeters. B<Must be only one char>.

=back

=item ROW

Takes an array of C<3> strings. You should not give more than one char to any of these parameters,
if you do.. it will probably destroy the output.. Unless you do it with the knowledge
of how it will end up. An example: C<['|','|','+']>

=over 4

=item *

LEFT - Define the char used for the left side of the table.

=item *

RIGHT - Define the char used for the right side of the table.

=item *

DELIMETER - Defines the char used for the delimeters.

=back

=back

Examples:

The easiest way:

 print $t;

Explanatory example:

 print $t->draw( ['L','R','l','D'],  # LllllllDllllllR
                 ['L','R','D'],      # L info D info R
                 ['L','R','l','D'],  # LllllllDllllllR
                 ['L','R','D'],      # L info D info R
                 ['L','R','l','D']   # LllllllDllllllR
                );

Nice example:

 print $t->draw( ['.','.','-','-'],   # .-------------.
                 ['|','|','|'],       # | info | info |
                 ['|','|','-','-'],   # |-------------|
                 ['|','|','|'],       # | info | info |
                 [' \\','/ ','_','|'] #  \_____|_____/
                );

Nice example2:

 print $t->draw( ['.=','=.','-','-'],   # .=-----------=.
                 ['|','|','|'],         # | info | info |
                 ['|=','=|','-','+'],   # |=-----+-----=|
                 ['|','|','|'],         # | info | info |
                 ["'=","='",'-','-']    # '=-----------='
                );

With Options:

 $t->setOptions('drawRowLine',1);
 print $t->draw( ['.=','=.','-','-'],   # .=-----------=.
                 ['|','|','|'],         # | info | info |
                 ['|-','-|','=','='],   # |-===========-|
                 ['|','|','|'],         # | info | info |
                 ["'=","='",'-','-'],   # '=-----------='
                 ['|=','=|','-','+']    # rowseperator
                );
 Which makes this output:
   .=-----------=.
   | col1 | col2 |
   |-===========-|
   | info | info |
   |=-----+-----=| <-- rowseperator between each row
   | info | info |
   '=-----------='

A tips is to enable allowANSI, and use the extra charset in your terminal to create
a beautiful table. But don't expect to get good results if you use ANSI-formatted table
with $t->drawPage.

B<User-defined subroutines for aligning>

If you want to format your text more throughoutly than "auto", or think you
have a better way of aligning text; you can make your own subroutine.

  Here's a exampleroutine that aligns the text to the right.
  
  sub myownalign_cb {
    my ($text,$length,$count,$strict) = @_;
    $text = (" " x ($length - $count)) . $text;
    return substr($text,0,$length) if ($strict);
    return $text;
  }

  $t->alignCol('Info',\&myownalign_cb);

B<User-defined subroutines for counting>

This is a feature to use if you are not happy with the internal allowHTML or allowANSI
support. Given is an example of how you make a count-callback that makes ASCIITable support
ANSI codes inside the table. (would make the same result as setting allowANSI to 1)

  $t->setOptions('cb_count',\&myallowansi_cb);
  sub myallowansi_cb {
    $_=shift;
    s/\33\[(\d+(;\d+)?)?[musfwhojBCDHRJK]//g;
    return length($_);
  }

=cut

sub drawit {scalar shift()->draw()}

=head2 drawPage($page,@topdesign,@toprow,@middle,@middlerow,@bottom,@rowline)

If you don't want your table to be wider than your screen you can use this
with $t->setOptions('outputWidth',40) to set the max size of the output.

Example:

  $t->setOptions('outputWidth',80);
  for my $page (1..$t->pageCount()) {
    print $t->drawPage($page)."\n";
    print "continued..\n\n";
  }

=cut

sub drawPage {
  my $self = shift;
  my ($pagenum,$top,$toprow,$middle,$middlerow,$bottom,$rowline) = @_;
  return $self->draw($top,$toprow,$middle,$middlerow,$bottom,$rowline,$pagenum);
}

# Thanks to Khemir Nadim ibn Hamouda <nadim@khemir.net> for code and idea.
sub getPart {
  my ($self,$page,$text) = @_;
  my $offset=0;

  return $text unless $page > 0;
  $text =~ s/\n$//;

  $self->prepareParts() if (scalar(@{$self->{tbl_cuts}}) < 1);
  $offset += (@{$self->{tbl_cuts}}[$_] - 1) for(0..$page-2);

  return substr($text, $offset, @{$self->{tbl_cuts}}[$page-1]) . "\n" ;
}

sub draw {
  my $self = shift;
  my ($top,$toprow,$middle,$middlerow,$bottom,$rowline,$page) = @_;
  my ($tstart,$tstop,$tline,$tdelim) = defined($top) ? @{$top} : @{$self->{des_top}};
  my ($trstart,$trstop,$trdelim) = defined($toprow) ? @{$toprow} : @{$self->{des_toprow}};
  my ($mstart,$mstop,$mline,$mdelim) = defined($middle) ? @{$middle} : @{$self->{des_middle}};
  my ($mrstart,$mrstop,$mrdelim) = defined($middlerow) ? @{$middlerow} : @{$self->{des_middlerow}};
  my ($bstart,$bstop,$bline,$bdelim) = defined($bottom) ? @{$bottom} : @{$self->{des_bottom}};
  my ($rstart,$rstop,$rline,$rdelim) = defined($rowline) ? @{$rowline} : @{$self->{des_rowline}};
  my $contents=""; $page = defined($page) ? $page : 0;

  delete $self->{cache_TableWidth}; # Clear cache
  $self->calculateColWidths;

  $contents .= $self->getPart($page,$self->drawLine($tstart,$tstop,$tline,$tdelim)) unless $self->{options}{hide_FirstLine};
  if (defined($self->{options}{headingText})) {
    my $title = $self->{options}{headingText};
    if ($title =~ m/\n/) { # Multiline title-support
      my @lines = split(/\r?\n/,$title);
      foreach my $line (@lines) {
        $contents .= $self->getPart($page,$self->drawSingleColumnRow($line,$self->{options}{headingStartChar} || '|',$self->{options}{headingStopChar} || '|',$self->{options}{headingAlign} || 'center','title'));
      }
    } else {
      $contents .= $self->getPart($page,$self->drawSingleColumnRow($self->{options}{headingText},$self->{options}{headingStartChar} || '|',$self->{options}{headingStopChar} || '|',$self->{options}{headingAlign} || 'center','title'));
    }
    $contents .= $self->getPart($page,$self->drawLine($mstart,$mstop,$mline,$mdelim)) unless $self->{options}{hide_HeadLine};
  }

  unless ($self->{options}{hide_HeadRow}) {
		# multiline-column-support
		foreach my $row (@{$self->{tbl_multilinecols}}) {
			$contents .= $self->getPart($page,$self->drawRow($row,1,$trstart,$trstop,$trdelim));
		}
	}
  $contents .= $self->getPart($page,$self->drawLine($mstart,$mstop,$mline,$mdelim)) unless $self->{options}{hide_HeadLine};
  my $i=0;
  for (@{$self->{tbl_rows}}) {
    $i++;
    $contents .= $self->getPart($page,$self->drawRow($_,0,$mrstart,$mrstop,$mrdelim));
		if (($self->{options}{drawRowLine} && $self->{tbl_rowline}{$i} && ($i != scalar(@{$self->{tbl_rows}}))) || 
				(defined($self->{tbl_lines}{$i}) && $self->{tbl_lines}{$i} && ($i != scalar(@{$self->{tbl_rows}})) && ($i != scalar(@{$self->{tbl_rows}})))) {
	    $contents .= $self->getPart($page,$self->drawLine($rstart,$rstop,$rline,$rdelim)) 
		}
  }
  $contents .= $self->getPart($page,$self->drawLine($bstart,$bstop,$bline,$bdelim)) unless $self->{options}{hide_LastLine};

  return $contents;
}

# nifty subs

# Replaces length() because of optional HTML and ANSI stripping
sub count {
  my ($self,$str) = @_;

  if (defined($self->{options}{cb_count}) && ref($self->{options}{cb_count}) eq 'CODE') {
    my $ret = eval { return &{$self->{options}{cb_count}}($str); };
    return $ret if (!$@);
    do { $self->reperror("Error: 'cb_count' callback returned error, ".$@); return 1; } if ($@);
  }
  elsif (defined($self->{options}{cb_count}) && ref($self->{options}{cb_count}) ne 'CODE') {
    $self->reperror("Error: 'cb_count' set but no valid callback found, found ".ref($self->{options}{cb_count}));
    return length($str);
  }
  $str =~ s/<.+?>//g if $self->{options}{allowHTML};
  $str =~ s/\33\[(\d+(;\d+)?)?[musfwhojBCDHRJK]//g if $self->{options}{allowANSI}; # maybe i should only have allowed ESC[#;#m and not things not related to
  $str =~ s/\33\([0B]//g if $self->{options}{allowANSI};                           # color/bold/underline.. But I want to give people as much room as they need.

  return length($str);
}

sub align {

  my ($self,$text,$dir,$length,$strict) = @_;

  if ($dir =~ /auto/i) {
    if ($text =~ /^-?\d+([.,]\d+)*[%\w]?$/) {
      $dir = 'right';
    } else {
      $dir = 'left';
    }
  }
  if (ref($dir) eq 'CODE') {
    my $ret = eval { return &{$dir}($text,$length,$self->count($text),$strict); };
    return 'CB-ERR' if ($@);
    # Removed in v0.14 # return 'CB-LEN-ERR' if ($self->count($ret) != $length);
    return $ret;
  } elsif ($dir =~ /right/i) {
    my $visuallen = $self->count($text);
    my $reallen = length($text);
    if ($length - $visuallen > 0) {
      $text = (" " x ($length - $visuallen)).$text;
    }
    return substr($text,0,$length - ($visuallen-$reallen)) if ($strict);
    return $text;
  } elsif ($dir =~ /left/i) {
    my $visuallen = $self->count($text);
    my $reallen = length($text);
    if ($length - $visuallen > 0) {
      $text = $text.(" " x ($length - $visuallen));
    }
    return substr($text,0,$length - ($visuallen-$reallen)) if ($strict);
    return $text;
  } elsif ($dir =~ /justify/i) {
    		my $visuallen = $self->count($text);
		my $reallen = length($text);
		$text = substr($text,0,$length - ($visuallen-$reallen)) if ($strict);
		if ($self->count($text) < $length - ($visuallen-$reallen)) {
			$text =~ s/^\s+//; # trailing whitespace
			$text =~ s/\s+$//; # tailing whitespace

			my @tmp = split(/\s+/,$text); # split them words

			if (scalar(@tmp)) {
				my $extra = $length - $self->count(join('',@tmp)); # Length of text without spaces

				my $modulus = $extra % (scalar(@tmp)); # modulus
				$extra = int($extra / (scalar(@tmp))); # for each word

				$text = '';
				foreach my $word (@tmp) {
					$text .= $word . (' ' x $extra); # each word
					if ($modulus) {
						$modulus--;
						$text .= ' '; # the first $modulus words, to even out
					}
				}
			}
		}
	  return $text; # either way, output text
  } elsif ($dir =~ /center/i) {
    my $visuallen = $self->count($text);
    my $reallen = length($text);
    my $left = ( $length - $visuallen ) / 2;
    # Someone tell me if this is matematecally totally wrong. :P
    $left = int($left) + 1 if ($left != int($left) && $left > 0.4);
    my $right = int(( $length - $visuallen ) / 2);
    $text = ($left > 0 ? " " x $left : '').$text.($right > 0 ? " " x $right : '');
    return substr($text,0,$length) if ($strict);
    return $text;
  } else {
    return $self->align($text,'auto',$length,$strict);
  }
}

sub TIEARRAY {
  my $self = shift;

	return bless { workaround => $self } , ref $self;
}
sub FETCH {
  shift->{workaround}->reperror('usage: push @$t,qw{ one more row };');
  return undef;
}
sub STORE {
  my $self = shift->{workaround};
  my ($index, $value) = @_;

  $self->reperror('usage: push @$t,qw{ one more row };');
}
sub FETCHSIZE {return 0;}
sub STORESIZE {return;}

# PodMaster should be really happy now, since this was in his wishlist. (ref: http://perlmonks.thepen.com/338456.html)
sub PUSH {
  my $self = shift->{workaround};
  my @list = @_;

  if (scalar(@list) > scalar(@{$self->{tbl_cols}})) {
    $self->reperror("too many elements added");
    return;
  }

  $self->addRow(@list);
}

sub reperror {
  my $self = shift;
  print STDERR Carp::shortmess(shift) if $self->{options}{reportErrors};
}

# Best way I could think of, to search the array.. Please tell me if you got a better way.
sub find {
  return undef unless defined $_[1];
  grep {return $_ if @{$_[1]}[$_] eq $_[0];} (0..scalar(@{$_[1]})-1);
  return undef;
}

1;

__END__

=head1 FEATURES

In case you need to know if this module has what you need, I have made this list
of features included in Text::ASCIITable.

=over 4

=item Configurable layout

You can easily alter how the table should look, in many ways. There are a few examples
in the draw() section of this documentation. And you can remove parts of the layout
or even add a heading-part to the table.

=item Text Aligning

Align the text in a column auto(matically), left, right, center or justify. Usually you want to align text
to right if you only have numbers in that row. The 'auto' direction aligns text to left, and numbers
to the right. The 'justify' alignment evens out your text on each line, so the first and the last word
always are at the beginning and the end of the current line. This gives you the newspaper paragraph look.
You can also use your own subroutine as a callback-function to align your text.
 
=item Multiline support in rows

With the \n(ewline) character you can have rows use more than just one line on
the output. (This looks nice with the drawRowLine option enabled)

=item Wordwrap support

You can set a column to not be wider than a set amount of characters. If a line exceedes
for example 30 characters, the line will be broken up in several lines.

=item HTML support

If you put in <HTML> tags inside the rows, the output would usually be broken when
viewed in a browser, since the browser "execute" the tags instead of displaying it.
But if you enable allowHTML. You are able to write html tags inside the rows without the
output being broken if you display it in a browser. But you should not mix this with
wordwrap, since this could make undesirable results.

=item ANSI support

Allows you to decorate your tables with colors or bold/underline when you display
your tables to a terminal window.

=item Page-flipping support

If you don't want the table to get wider than your terminal-width.

=item Errorreporting

If you write a script in perl, and don't want users to be notified of the errormessages
from Text::ASCIITable. You can easily turn of error reporting by setting reportErrors to 0.
You will still get an 1 instead of undef returned from the function.

=back

=head1 REQUIRES

Exporter, Carp

=head1 AUTHOR

Håkon Nessjøen, <lunatic@cpan.org>

=head1 VERSION

Current version is 0.22.

=head1 COPYRIGHT

Copyright 2002-2011 by Håkon Nessjøen.
All rights reserved.
This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

Text::FormatTable, Text::Table, Text::SimpleTable

=cut
