#!/usr/local/bin/perl
# user_grace_save.cgi
# Update the grace times for users on some filesystem

require './quota-lib.pl';
&ReadParse();
$whatfailed = $text{'ugraces_esave'};
$access{'ugrace'} && &can_edit_filesys($in{'filesys'}) ||
	&error($text{'ugraces_eedit'});

if ($in{'bdef'}) { push(@args, 0, 0); }
elsif ($in{'btime'} !~ /^[0-9\.]+$/)
	{ &error(&text('ugraces_enumber', $in{'btime'})); }
else { push(@args, ($in{'btime'}, $in{'bunits'})); }

if ($in{'fdef'}) { push(@args, 0, 0); }
elsif ($in{'ftime'} !~ /^[0-9\.]+$/)
	{ &error(&text('ugraces_enumber', $in{'ftime'})); }
else { push(@args, ($in{'ftime'}, $in{'funits'})); }

&edit_user_grace($in{'filesys'}, @args);
&webmin_log("grace", "user", $in{'filesys'}, \%in);
&redirect("list_users.cgi?dir=".&urlize($in{'filesys'}));

