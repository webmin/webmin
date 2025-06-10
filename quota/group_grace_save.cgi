#!/usr/local/bin/perl
# group_grace_save.cgi
# Update the grace times for groups on some filesystem

require './quota-lib.pl';
&ReadParse();
$whatfailed = $text{'ggraces_esave'};
$access{'ggrace'} && &can_edit_filesys($in{'filesys'}) ||
	&error($text{'ggraces_eedit'});

if ($in{'bdef'}) { push(@args, 0, 0); }
elsif ($in{'btime'} !~ /^[0-9\.]+$/)
	{ &error(&text('ggraces_enumber', $in{'btime'})); }
else { push(@args, ($in{'btime'}, $in{'bunits'})); }

if ($in{'fdef'}) { push(@args, 0, 0); }
elsif ($in{'ftime'} !~ /^[0-9\.]+$/)
	{ &error(&text('ggraces_enumber', $in{'ftime'})); }
else { push(@args, ($in{'ftime'}, $in{'funits'})); }

&edit_group_grace($in{'filesys'}, @args);
&webmin_log("grace", "group", $in{'filesys'}, \%in);
&redirect("list_groups.cgi?dir=".&urlize($in{'filesys'}));

