#!/usr/bin/perl
# setup.cgi
# Create a default nftables ruleset

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
if ($in{'action'} eq 'create') {
    my $type = $in{'type'};
    my @tables;
    if ($type eq 'allow_all') {
        @tables = create_allow_all_ruleset();
    }
    elsif ($type eq 'deny_incoming') {
        @tables = create_deny_incoming_ruleset();
    }
    elsif ($type eq 'deny_all') {
        @tables = create_deny_all_ruleset();
    }
    else {
        error($text{'setup_invalid_type'});
    }

    my $error = save_configuration(@tables);
    if ($error) {
        error(text('setup_failed', $error));
    }
    $error = apply_restore();
    if ($error) {
        error(text('setup_failed', $error));
    }
    webmin_log("setup", "create", $type);
    redirect("index.cgi");
}

ui_print_header(undef, $text{'setup_title'}, "", "intro", 1, 1);

print "<h3>$text{'setup_header'}</h3>";
my $webmin_port = get_webmin_port();
print "<p>$text{'setup_desc'}</p>";
print "<p>",text('setup_deny_note', $webmin_port),"</p>";

print ui_form_start("setup.cgi");
print ui_hidden("action", "create");

my @type_opts = (
    [ 'allow_all',     $text{'setup_allow_all'} . "<br>" ],
    [ 'deny_incoming', $text{'setup_deny_incoming'} . "<br>" ],
    [ 'deny_all',      $text{'setup_deny_all'} ],
);
print ui_radio("type", "allow_all", \@type_opts);

print ui_form_end([ [ undef, $text{'setup_create'} ] ]);

sub create_allow_all_ruleset
{
    my @tables;
    my $table = {
        'name' => 'inet_filter',
        'family' => 'inet',
        'rules' => [],
        'sets' => {},
        'chains' => {
            'input' => {
                'type' => 'filter',
                'hook' => 'input',
                'priority' => 0,
                'policy' => 'accept'
            },
            'forward' => {
                'type' => 'filter',
                'hook' => 'forward',
                'priority' => 0,
                'policy' => 'accept'
            },
            'output' => {
                'type' => 'filter',
                'hook' => 'output',
                'priority' => 0,
                'policy' => 'accept'
            }
        }
    };
    push(@tables, $table);
    return @tables;
}

sub create_deny_incoming_ruleset
{
    my @tables;
    my $webmin_port = get_webmin_port();
    my $table = {
        'name' => 'inet_filter',
        'family' => 'inet',
        'rules' => [
            {
                'text' => 'ct state established,related accept',
                'chain' => 'input'
            },
            {
                'text' => 'iif "lo" accept',
                'chain' => 'input'
            },
            {
                'text' => 'tcp dport 22 accept',
                'chain' => 'input'
            },
            {
                'text' => "tcp dport $webmin_port accept",
                'chain' => 'input'
            }
        ],
        'sets' => {},
        'chains' => {
            'input' => {
                'type' => 'filter',
                'hook' => 'input',
                'priority' => 0,
                'policy' => 'drop'
            },
            'forward' => {
                'type' => 'filter',
                'hook' => 'forward',
                'priority' => 0,
                'policy' => 'accept'
            },
            'output' => {
                'type' => 'filter',
                'hook' => 'output',
                'priority' => 0,
                'policy' => 'accept'
            }
        }
    };
    push(@tables, $table);
    return @tables;
}

sub create_deny_all_ruleset
{
    my @tables;
    my $webmin_port = get_webmin_port();
    my $table = {
        'name' => 'inet_filter',
        'family' => 'inet',
        'rules' => [],
        'sets' => {},
        'chains' => {
            'input' => {
                'type' => 'filter',
                'hook' => 'input',
                'priority' => 0,
                'policy' => 'drop'
            },
            'forward' => {
                'type' => 'filter',
                'hook' => 'forward',
                'priority' => 0,
                'policy' => 'drop'
            },
            'output' => {
                'type' => 'filter',
                'hook' => 'output',
                'priority' => 0,
                'policy' => 'drop'
            }
        }
    };
    $table->{'rules'} = [
        {
            'text' => 'ct state established,related accept',
            'chain' => 'output'
        },
        {
            'text' => 'iif "lo" accept',
            'chain' => 'input'
        },
        {
            'text' => 'oif "lo" accept',
            'chain' => 'output'
        },
        {
            'text' => 'tcp dport 22 accept',
            'chain' => 'input'
        },
        {
            'text' => "tcp dport $webmin_port accept",
            'chain' => 'input'
        }
    ];
    push(@tables, $table);
    return @tables;
}

ui_print_footer("/", $text{'index'});
