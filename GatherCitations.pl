#!/usr/bin/env perl6

use JSON::Fast;

my $projectsfile = 'projects.txt';
my %citing;
%citing<__date> = DateTime.new(now).Str;
say "Downloading projects file";

update $projectsfile, "./archive/projects_{ %citing<__date> }.txt";

my $list = try from-json( $projectsfile.IO.slurp) ;
if $! {
	die "Cannot parse $projectsfile as JSON: $!";
}
my $c = 0;

for $list.list -> $mod {
	unless %citing{$mod<name>}:exists and %citing{$mod<name>} gt $mod<version> {
		%citing{$mod<name>} = {};
		with $mod<depends> {
			for $mod<depends>.flat { %citing{$mod<name>}{$_} = $mod<version> }
		}
	}
}

say "\nCitation data gathered. Stored in './archive/CitationData_{%citing<__date>}'. Use CitationAnalyse.pl to process.";

"./archive/CitationData_{%citing<__date>}".IO.spurt: to-json(%citing);


sub update ($projectsfile, $store) {
        try unlink $projectsfile;
        my $url = 'http://ecosystem-api.p6c.org/projects.json';
        my $s;
        my $has-http-ua = try require HTTP::UserAgent;
        if $has-http-ua {
            my $ua = ::('HTTP::UserAgent').new;
            my $response = $ua.get($url);
            $projectsfile.IO.spurt: $response.decoded-content;
            $store.IO.spurt: $response.decoded-content;
        } else {
            # Makeshift HTTP::Tiny
            $s = IO::Socket::INET.new(:host<ecosystem-api.p6c.org>, :port(80));
            $s.print("GET /projects.json HTTP/1.0\r\nHost: ecosystem-api.p6c.org\r\n\r\n");
            my ($buf, $g) = '';
            
            my $http-header = $s.get;
            
            if $http-header !~~ /'HTTP/1.'<[01]>' 200 OK'/ {
                die "can't download projects file: $http-header";
            }
            
            $buf ~= $g while $g = $s.get;
            
            $projectsfile.IO.spurt: $buf.split(/\r?\n\r?\n/, 2)[1];
	    $store.IO.spurt: $buf.split(/\r?\n\r?\n/, 2)[1];
    }   
            
        CATCH {
            die "Could not download module metadata: {$_.message}"
        }
    }

