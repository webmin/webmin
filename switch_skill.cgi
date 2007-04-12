#!/usr/local/bin/perl
# switch_skill.cgi
# Change the skill level of the current user

require './web-lib.pl';
&init_config();
&ReadParse();
$gconfig{'skill_'.$base_remote_user} = $in{'skill'};
&write_file("$config_directory/config", \%gconfig);
&redirect("/?cat=$in{'cat'}");

