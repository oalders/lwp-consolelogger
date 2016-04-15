requires "Data::Printer" => "0.36";
requires "DateTime" => "0";
requires "HTML::Restrict" => "0";
requires "HTTP::Body" => "0";
requires "HTTP::CookieMonster" => "0";
requires "JSON::MaybeXS" => "1.003005";
requires "Log::Dispatch" => "0";
requires "Module::Load::Conditional" => "0";
requires "Moo" => "0";
requires "MooX::StrictConstructor" => "0";
requires "Parse::MIME" => "0";
requires "String::Trim" => "0";
requires "Sub::Exporter" => "0";
requires "Term::Size::Any" => "0";
requires "Text::SimpleTable::AutoWidth" => "0.09";
requires "Try::Tiny" => "0";
requires "Type::Tiny" => "0";
requires "Types::Common::Numeric" => "0";
requires "Types::Standard" => "0";
requires "URI::Query" => "0";
requires "URI::QueryParam" => "0";
requires "XML::Simple" => "0";
requires "perl" => "5.006";
requires "strict" => "0";
requires "warnings" => "0";
recommends "HTML::FormatText::Lynx" => "23";

on 'build' => sub {
  requires "Module::Build" => "0.28";
};

on 'test' => sub {
  requires "HTML::FormatText::WithLinks" => "0";
  requires "HTTP::Request" => "0";
  requires "LWP::UserAgent" => "0";
  requires "Log::Dispatch::Array" => "0";
  requires "Path::Tiny" => "0";
  requires "Plack::Handler::HTTP::Server::Simple" => "0.016";
  requires "Plack::Test" => "0";
  requires "Plack::Test::Agent" => "0";
  requires "Test::FailWarnings" => "0";
  requires "Test::Fatal" => "0";
  requires "Test::Most" => "0";
  requires "URI::file" => "0";
  requires "WWW::Mechanize" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "Module::Build" => "0.28";
};

on 'configure' => sub {
  suggests "JSON::PP" => "2.27300";
};

on 'develop' => sub {
  requires "Test::CPAN::Changes" => "0.19";
  requires "Test::Spelling" => "0.12";
};
