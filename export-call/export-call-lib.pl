# Test for a foreign module call

use WebminCore;
&init_config();

sub print_stuff
{
print "Hello world from $module_name<p>\n";
}

sub die_now
{
print "About to exit ..<br>\n";
exit(1);
print "After exit!<p>\n";
}

sub print_text
{
print $text{'my_msg'},"<p>\n";

print &text('my_subs', 'Joe'),"<p>\n";
}

1;

