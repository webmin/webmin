#!/usr/local/bin/perl
# Delete auto-whitelist entries

require './spam-lib.pl';
&error_setup($text{'dawl_err'});
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("awl");
&can_edit_awl($in{'user'}) || &error($text{'dawl_ecannot'});
$conf = &get_config();

# Check stuff
&open_auto_whitelist_dbm($in{'user'}) || &error($text{'dawl_eopen'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'dawl_enone'});

if ($in{'white'}) {
	# Add to whitelist
	@d = map { s/\|.*$//; $_ } @d;
	@from = map { @{$_->{'words'}} } &find("whitelist_from", $conf);
	@from = &unique(@from, @d);
	&save_directives($conf, "whitelist_from", \@from, 1);
	&flush_file_lines();
	}
elsif ($in{'black'}) {
	# Add to blacklist
	@d = map { s/\|.*$//; $_ } @d;
	@from = map { @{$_->{'words'}} } &find("blacklist_from", $conf);
	@from = &unique(@from, @d);
	&save_directives($conf, "blacklist_from", \@from, 1);
	&flush_file_lines();
	}
else {
	# Delete from AWL hash
	foreach $d (@d) {
		delete($awl{$d});
		delete($awl{$d."|totscore"});
		}
	}

&close_auto_whitelist_dbm();
&redirect("edit_awl.cgi?search=".&urlize($in{'search'}).
	  "&user=".&urlize($in{'user'}).
	  "&file=".&urlize($in{'file'}).
	  "&title=".&urlize($in{'title'}));

