#!/usr/local/bin/perl
# conf_logging.cgi
# Display global logging options
use strict;
use warnings;
our (%access, %text, %in);
our (@syslog_levels, @severities, @cat_list);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'logging_ecannot'});
&ui_print_header(undef, $text{'logging_title'}, "",
		 undef, undef, undef, undef, &restart_links());
&ReadParse();
my $conf = &get_config();
my $logging = &find("logging", $conf);
my $mems = $logging ? $logging->{'members'} : [ ];

# Start of tabs for channels and categories
my @tabs = ( [ "chans", $text{'logging_chans'}, "conf_logging.cgi?mode=chans" ],
	  [ "cats", $text{'logging_cats'}, "conf_logging.cgi?mode=cats" ] );
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "chans", 1);

print &ui_tabs_start_tab("mode", "chans");
print $text{'logging_chansdesc'},"<p>\n";

# Add default channels to table
my @table = ( );
my @defchans = ( { 'name' => 'default_syslog',
		'syslog' => 'daemon',
		'severity' => 'info' },
	      { 'name' => 'default_debug',
		'file' => 'named.run',
		'severity' => 'dynamic' },
	      { 'name' => 'default_stderr',
		'fd' => 'stderr',
		'severity' => 'info' },
	      { 'name' => 'null',
		'null' => 1 } );
foreach my $c (@defchans) {
	push(@table, [
		$c->{'name'},
		$c->{'syslog'} ? $c->{'syslog'} :
		$c->{'file'} ? $text{'logging_file'}.
			       " <tt>".$c->{'file'}."</tt>" :
		$c->{'fd'} ? $text{'logging_fd'}." <tt>".$c->{'fd'}."</tt>" :
			     $text{'logging_null'},
		$c->{'severity'} || "<i>$text{'logging_any'}</i>",
		"", "", "",
		]);
	}

# Add user-defined channels
# XXX
my @chans = &find("channel", $mems);
my @channames = ( (map { $_->{'value'} } @chans) ,
	       'default_syslog', 'default_debug', 'default_stderr', 'null' );
push(@chans, { });
for(my $i=0; $i<@chans; $i++) {
	my $cmems = $chans[$i]->{'members'};
	my $file = &find("file", $cmems);
	my $filestr = $file ? join(" ", @{$file->{'values'}}) : "";
	my $syslog = &find_value("syslog", $cmems);
	my $null = &find("null", $cmems);
	my $stderr = &find("stderr", $cmems);
	my @cols;

	# Channel name
	push(@cols, &ui_textbox("cname_$i", $chans[$i]->{'value'}, 10));

	# Log destination
	my @dests;
	my $to = $file ? 0 : $syslog ? 1 : $stderr ? 3 : $null ? 2 : 0;
	push(@dests, [ 0, $text{'logging_file'},
		       &ui_filebox("file_$i", $file->{'value'}, 40) ]);
	push(@dests, [ 1, $text{'logging_syslog'},
		       &ui_select("syslog_$i", $syslog,
				  \@syslog_levels, 1, 0, $syslog ? 1 : 0) ]);
	push(@dests, [ 3, $text{'logging_stderr'} ]);
	push(@dests, [ 2, $text{'logging_null'} ]);
	push(@cols, &ui_radio_table("to_$i", $to, \@dests));

	# Severity
	my $sev = &find("severity", $cmems);
	push(@cols, &ui_select("sev_$i", $sev->{'value'},
		[ [ "", "&nbsp;" ],
		  map { [ $_, $_ eq 'debug' ? $text{'logging_debug'} :
			      $_ eq 'dynamic' ? $text{'logging_dyn'} : $_ ] }
		      @severities ],
		1, 0, 0, 0,
		"onChange='form.debug_$i.disabled = form.sev_$i.value != \"debug\"'"
		)." ".
		&ui_textbox("debug_$i", $sev->{'value'} eq 'debug' ?
					   $sev->{'values'}->[1] : "", 5,
			    $sev->{'value'} ne "debug"));

	# Log category, severity and time
	push(@cols, &yes_no_default("print-category-$i",
			&find_value("print-category", $cmems)));
	push(@cols, &yes_no_default("print-severity-$i",
			&find_value("print-severity", $cmems)));

	push(@cols, &yes_no_default("print-time-$i",
			&find_value("print-time", $cmems)));

	push(@table, \@cols);
	}

# Output the channels table
print &ui_form_columns_table(
        "save_logging.cgi",
        [ [ undef, $text{'save'} ] ],
        0,
        undef,
        [ [ 'mode', 'chans' ] ],
	[ $text{'logging_cname'}, $text{'logging_to'}, $text{'logging_sev'},
	  $text{'logging_pcat2'}, $text{'logging_psev2'},
	  $text{'logging_ptime2'} ],
	100,
	\@table,
	undef,
	1);

print &ui_tabs_end_tab("mode", "chans");

# Start of categories tab
print &ui_tabs_start_tab("mode", "cats");
print $text{'logging_catsdesc'},"<p>\n";

# Build table of categories
@table = ( );
my @cats = ( &find("category", $mems), { } );
for(my $i=0; $i<@cats; $i++) {
	my %cchan;
	foreach my $c (@{$cats[$i]->{'members'}}) {
		$cchan{$c->{'name'}}++;
		}
	push(@table, [
		&ui_select("cat_$i", $cats[$i]->{'value'},
			   [ [ "", "&nbsp;" ], @cat_list ],
			   1, 0, $cats[$i]->{'value'} ? 1 : 0),
		join(" ", map { &ui_checkbox("cchan_$i", $_, $_, $cchan{$_}) }
			      @channames)
		]);
	}

# Show the table
print &ui_form_columns_table(
	"save_logging.cgi",
	[ [ undef, $text{'save'} ] ],
	0,
	undef,
	[ [ 'mode', 'cats' ] ],
	[ $text{'logging_cat'}, $text{'logging_cchans'} ],
	100,
	\@table,
	undef,
	1);

print &ui_tabs_end_tab("mode", "cats");
print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});

# yes_no_default(name, value)
sub yes_no_default
{
my ($n, $v) = @_;
return &ui_select($n, lc($v), [ [ '', $text{'default'} ],
				[ 'yes', $text{'yes'} ],
				[ 'no', $text{'no'} ] ]);
}

