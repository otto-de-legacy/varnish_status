varnish status
==============
varnish status provides basic information about varnish backend and director health.
Data is represented as HTML and JSON.

Prerequisitions
---------------
You should have installed ruby-1.9.3 and the bundler rubygem (gem install bundler).
The user running varnish_status need access to varnishadm on the machine.

Installation
------------
clone the repository on the same machine, where you run a varnish instance.

    git clone https://github.com/otto-de/varnish_status
    cd varnish_status.git
    bundle install
    bundle exec puma

Configuration
-------------
varnish\_status is using the varnish command line tool varnishadm. Define your specific varnishadm command and special parameters in the config.yaml.

Namingconvention for backends in vcl
------------------------------------
varnish\_status expects, you are using naming conventions in your vcl for your backends, \<backend\_name\>\_\<pool\_name\>. Example:

      backend server1_pool1 { ... }  
      backend server2_pool1 { ... }

      director pool1 round-robin { 
        { .backend = server1_pool1; }
        { .backend = server2_pool1; }
      }    

Because the backend.list command in varnishadm does not group backends to directors automatically, varnish\_status is using the underscore as seperator to group backends in directors. If no underscore is found in the backend name, varnish\_status create a group for each backend.

Testing
-------
varnish\_status is tested with rspec, see tests/*.rb for details. You can run the tests with:

    rake spec

Run in production
-----------------
To run varnish\_status in production, we recommend using unicorn (http://rubygems.org/gems/unicorn)
For testing you can run varnish_status in a puma instance. Just checkout, edit the config.yaml, run a bundle install and bundle exec puma.

Open http://myhosthame:9292/ for the HTML reprensation.

Open http://myhostname:9292/internal/status for a basic status json.

Open http://myhostname:9292/internal/details for more details in the json status response.

