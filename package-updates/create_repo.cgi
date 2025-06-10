#!/usr/local/bin/perl
# Create one new repository

require './package-updates-lib.pl';
&ReadParse();
&error_setup($text{'repos_err_create'});

$repo = &software::create_repo_parse(\%in);
&error($repo) if (!ref($repo));
&software::create_package_repo($repo);
&webmin_log("create", "repo", $repo->{'id'});
&redirect("index.cgi?tab=repos");
