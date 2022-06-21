# Hoist
Recursively render a directory tree of `liquid` template files to stdout, given a configuration environment in `YAML`. Primary use case is a lightweight renderer for portable `Kubernetes` manifests when `Helm` is too heavy.

## Local Installation

Clone this repository and execute

    $ rake install

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hoist'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hoist

## Usage
```
Usage: hoist COMMAND [OPTIONS] ARGS

  Commands:

    apply   Render the given template file(s) and run kubectl apply on the results. If given
            directory will recursively traverse.

    decrypt Decrypt the contents of the config file using an RSA private key. If no config
            file option was specified the command will look for a "settings.yml" file in the
            current directory. If not OUTPUT_FILE was specified, the command will print the
            encrypted content to stdout.

    delete  Render the given template file(s) and run kubectl delete on the results. If given
            directory will recursively traverse.

    encrypt Encrypt the contents of the config file using an RSA public key. If no config file
            option was specified the command will look for a "settings.yml" file in the current
            directory. If not OUTPUT_FILE was specified, the command will print the encrypted
            content to stdout.

    help    Display global or [command] help documentation

    render  Render the given template file(s) to stdout. If given directory will recursively
            traverse.

  Global Options:

    -c, --config FILE    Load config data for your commands to use.
                          By default hoist will look for a "settings.yml" file in the current
                          directory.

    -k, --key FILE       Path to your RSA private key in PEM format. Defaults to a local file named
                         "key.pem" first, then to "~/.ssh/id_rsa"

    -h, --help           Display help documentation

    -v, --version        Display version information

    -t, --trace          Display backtrace when an error occurs
```

## Encrypted Configuration
To use the encrypted configuration file feature you need a RSA key pair, consisting of a Public Key, and a Private Key. Such a key pair can be generated on most machines with the following command:

```sh
ssh-keygen -t rsa -b 4096 -m PEM
```

#### Public Key
Hoist uses the `Public Key` to encrypt the contents of a `settings.yml` file. The `Public Key` can be freely shared with anyone who should be able to create an encrypted settings file. You can export a shareable `Public Key` from a key pair as generated above like so:

```sh
ssh-keygen -e -m PEM -f <PRIVATE_KEY > <PUBLIC_KEY>
```

#### Private Key
Hoist uses the `Private Key` to decrypt the contents of a `settings.eyml` (encrypted YAML) file. The `Private Key` should be kept secret and protected with a strong passphrase. The `settings.eyml` file can be safely added to your version control repository.

## Example
Let's say you had a Kubernetes manifest in the form of a Liquid template for your application as `myapp.hoist` with the following contents:

```yaml
---
apiVersion: v1
 kind: ConfigMap
 metadata:
   name: {{app.name}}-config
   namespace: default
 data:
   MYSQL_HOST: {{mysql.host}}
   MYSQL_POST: {{mysql.port}}
   MYSQL_USER: {{mysql.user}}
   MYSQL_PASSWORD: {{mysql.password}}
   APP_SECRET: {{app.secret}}
 ---
 apiVersion: apps/v1
 kind: Deployment
 metadata:
   name: {{app.name}}-deployment
   labels:
     app: {{app.name}}
 spec:
   replicas: 2
   selector:
     matchLabels:
       app: {{app.name}}
   template:
     metadata:
       labels:
         app: {{app.name}}
     spec:
       containers:
       - name: {{app.name}}
         image: {{app.name}}:latest
         envFrom:
           - configMapRef:
             name: {{app.name}}-config
         ports:
         - name: {{app.name}}-port
           containerPort: {{app.port}}
 ---
 apiVersion: v1
 kind: Service
 metadata:
   name: {{app.name}}-service
 spec:
   type: ClusterIP
   ports:
   - name: "web"
     protocol: TCP
     port: {{app.port}}
     targetPort: {{app.port}}
   selector:
     app: {{app.name}}
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
 name: {{app.name}}-ingress
 annotations:
   kubernetes.io/ingress.class: nginx
   nginx.ingress.kubernetes.io/rewrite-target: /
spec:
 tls:
 - hosts:
   - {{app.host}}
   secretName: {{app.name}}-tls-secret
 rules:
 - host: {{app.host}}
   http:
     paths:
     - path: /
       backend:
         serviceName: {{app.name}}-service
         servicePort: {{app.port}}
```

You could specify a `settings.yml` file that contains the corresponding template values:

```yaml
app:
  host: myapp.foo-bar.com
  name: myapp
  port: 4000
  secret: ce51302ea812f919705bb39e56267f82
mysql:
  host: db-production
  user: myapp
  password: 08594b64f905cbe10ff723ff2b5cbb06
  port: 3306
```

Calling `hoist render myapp.hoist` will read configuration from the `settings.yml` file and render the `myapp.hoist` template to stdout. Similarly, calling `hoist apply myapp.hoist` will deploy the stack to your active `kubectl` context, and calling `hoist delete myapp.hoist` would remove the deployment.

Calling `hoist encrypt -c settings.yml settings.eyml` would encrypt the contents of the configuration file and store the encrypted version in a new filed named `settings.eyml`. You can now delete your `settings.yml` file and add the encrypted file to version control.

Now calling `hoist render myapp.hoist`, `hoist apply myapp.hoist` or `hoist delete myapp.hoist` will read configuration from the encrypted `settings.eyml` file and decrypt the contents using your RSA private key before taking the corresponding action.

Go ahead, and delete `settings.yml`. Now call `hoist render myapp.hoist` and it will still render the template.

Calling `hoist decrypt -c settings.eyml` would decrypt the contents of the secure configuration file and print the decrypted contents to stdout.

## Roadmap

#### Quality of Life
- [X] Better CLI with support for sub-commands
- [X] Basic ability to control Kubernetes cluster via `kubectl`
- [ ] Advanced Kubernetes interactions via API
- [ ] Translation of `docker-compose.yml` files to Kubernetes manifests

#### Data Sources for Configuration
- [X] Configuration from single `YAML` file
- [ ] Configuration from `Zookeeper`
- [ ] Configuration from `Etcd`
- [ ] Configuration from `Vault`
- [ ] Configuration from `AWS SMP`
- [ ] Configuration from `Consul`
- [ ] Configuration from `http` / `https` endpoints
- [ ] Configuration from `stdin`

#### Additional Filters for Templates
- [X] Base64 Encode
- [X] Base64 Decode
- [ ] MD5 Hash
- [ ] SHA256 Hash
- [ ] Random Number
- [ ] AES 256 Encrypt and Decrypt

#### Security
- [X] RSA Encrypt and Decrypt config file
- [X] Always prefer encrypted config file `settings.eyml` over unencrypted variant `settings.yml`


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kuyio/hoist. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Hoist project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
