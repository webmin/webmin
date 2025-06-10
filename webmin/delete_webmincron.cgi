#!/usr/local/bin/perl
# Delete or run some Webmin cron jobs

require './webmin-lib.pl';
&foreign_require("webmincron");
&ReadParse();

# Get jobs
@d = split(/\0/, $in{'d'});
@wcrons = grep { &indexof($_->{'id'}, @d) >= 0 }
		&webmincron::list_webmin_crons();

if ($in{'delete'}) {
	# Deleting some jobs
	&error_setup($text{'webmincron_derr'});
	@wcrons || &error($text{'webmincron_enone'});
	foreach my $w (@wcrons) {
		&webmincron::delete_webmin_cron($w);
		}
	&webmin_log("delete", "webmincron", scalar(@wcrons));
	&redirect("edit_webmincron.cgi");
	}
elsif ($in{'run'}) {
	# Running some jobs
	&error_setup($text{'webmincron_rerr'});
	@wcrons || &error($text{'webmincron_enone'});
	&ui_print_unbuffered_header(undef, $text{'webmincron_title'}, "");

	foreach my $w (@wcrons) {
		%minfo = &get_module_info($w->{'module'});
		print &text('webmincron_running',
			    $minfo{'desc'} || $w->{'module'},
			    "<tt>$w->{'func'}</tt>"),"<br>\n";
		print "<pre>\n";
		eval {
			local $main::error_must_die = 1;
			&foreign_require($w->{'module'}, $w->{'file'});
			if ($w->{'args'}) {
				&foreign_call($w->{'module'}, $w->{'func'},
					      @{$w->{'args'}});
				}
			else {
				&foreign_call($w->{'module'}, $w->{'func'});
				}
			};
		print "</pre>\n";
		if ($@) {
			print &text('webmincron_failed',
				    &html_escape($@)),"<p>\n";
			}
		else {
			print $text{'webmincron_done'},"<p>\n";
			}
		}

	&webmin_log("run", "webmincron", scalar(@wcrons));
	&ui_print_footer("", $text{'index_return'});
	}
else {
	&error($text{'webmincron_ebutton'});
	}
