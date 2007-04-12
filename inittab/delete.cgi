#!/usr/local/bin/perl
# Delete multiple inittab entries

require "./inittab-lib.pl";
&ReadParse();
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Do the delete
&lock_file($config{ 'inittab_file' });
@inittab = &parse_inittab();
foreach $d (reverse(@d)) {
	($init) = grep { $_->{'id'} eq $d } @inittab;
	if ($init) {
		&delete_inittab($init);
		}
	}
&unlock_file($config{ 'inittab_file' });

&webmin_log("delete", "inittabs", scalar(@d), \%in);
&redirect("");

