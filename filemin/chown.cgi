#!/usr/bin/perl

require './filemin-lib.pl';

&ReadParse();

get_paths();

if(!$in{'owner'} or !$in{'group'}) {
    &redirect("index.cgi?path=$path");
}

(my $login, my $pass, my $uid, my $gid) = getpwnam($in{'owner'});
my $grid = getgrnam($in{'group'});
my $recursive;
if($in{'recursive'} eq 'true') { $recursive = '-R'; } else { $recursive = ''; }

my @errors;

if(! defined $login) {
    push @errors, "<b>$in{'owner'}</b> $text{'error_user_not_found'}";
}

if(! defined $grid) {
    push @errors, "<b>$in{'group'}</b> $text{'error_group_not_found'}";
}

if (scalar(@errors) > 0) {
        print_errors(@errors);
} else {
    foreach $name (split(/\0/, $in{'name'})) {
#        if(!chown $uid, $grid, $cwd.'/'.$name) {
        if(system_logged("chown $recursive $uid:$grid ".quotemeta("$cwd/$name")) != 0) {
            push @errors, "$name - $text{'error_chown'}: $?";
        }
    }
    if (scalar(@errors) > 0) {
        print_errors(@errors);
    } else {
        &redirect("index.cgi?path=$path");
    }
}
