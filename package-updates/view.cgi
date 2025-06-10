#!/usr/local/bin/perl
# Show details of one package and available updates

require './package-updates-lib.pl';
&ui_print_header(undef, $text{'view_title'}, "");
&ReadParse();

# Get the package
@avail = &list_for_mode($in{'mode'}, 0);
($a) = grep { $_->{'name'} eq $in{'name'} &&
	      $_->{'system'} eq $in{'system'} } @avail;
@current = &list_current(0);
($c) = grep { $_->{'name'} eq $in{'name'} &&
              $_->{'system'} eq $in{'system'} } @current;
$p = $a || $c;

print &ui_form_start("save_view.cgi");
print &ui_hidden("name", $p->{'name'});
print &ui_hidden("system", $p->{'system'});
print &ui_hidden("version", $p->{'version'});
print &ui_hidden("mode", $in{'mode'});
print &ui_table_start($text{'view_header'}, undef, 2);

# Package name and type
print &ui_table_row($text{'view_name'}, $p->{'name'});
print &ui_table_row($text{'view_system'}, $text{'system_'.$p->{'system'}} ||
					  uc($p->{'system'}));
print &ui_table_row($text{'view_desc'}, $p->{'desc'});

# Current state
print &ui_table_row($text{'view_state'},
	$a && !$c ? "<font color=#00aa00>$text{'index_caninstall'}</font>" :
	!$a && $c ? "<font color=#ffaa00>".
                     &text('index_noupdate', $c->{'version'})."</font>" :
	&compare_versions($a, $c) > 0 ?
		    "<font color=#00aa00>".
		     &text('index_new', $a->{'version'})."</font>" :
		    &text('index_ok', $c->{'version'}));

# Version(s) available
if ($c) {
	print &ui_table_row($text{'view_cversion'},
		($c->{'epoch'} ? $c->{'epoch'}.":" : "").$c->{'version'});
	}
if ($a) {
	print &ui_table_row($text{'view_aversion'},
		($a->{'epoch'} ? $a->{'epoch'}.":" : "").$a->{'version'});
	}

# Source, if available
if ($a->{'source'}) {
	print &ui_table_row($text{'view_source'}, ucfirst($a->{'source'}));
	}

# Change log, if possible
if ($a) {
	$cl = &get_changelog($a);
	if ($cl) {
		print &ui_table_row($text{'view_changelog'},
			"<pre>".&html_escape($cl)."</pre>");
		}
	}

print &ui_table_end();

# Buttons to update / manage
@buts = ( );
if ($c && &foreign_available("software") && $c->{'software'}) {
	push(@buts, [ "software", $text{'view_software'} ]);
	}
if ($a && $c && &compare_versions($a, $c) > 0) {
	push(@buts, [ "update", $text{'view_update'} ]);
	}
elsif ($a && !$c) {
	push(@buts, [ "update", $text{'view_install'} ]);
	}
print &ui_form_end(\@buts);

&ui_print_footer("index.cgi?mode=$in{'mode'}&search=".
	          &urlize($in{'search'}),
		 $text{'index_return'});

