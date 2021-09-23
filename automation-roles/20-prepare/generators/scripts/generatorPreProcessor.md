# Methods provided by the preprocessor

[Chainable Methods](#chainable-methods)  
[Instance Methods](#instance-methods)


### initializing it

For convinience we call the instance of the GeneratorPreProcessor just "g".

```
g=GeneratorPreProcessor(attributes,fullConfig)

```

### doing a check

after having it initialized the g instance takes a single string parameter to query single paths from the attributes (the local config we want to pass to the single instance of the generator)

```
g('name')

g('infrastructure.type')
```

## Chainable Methods

### .isRequired()
Will do a check if the property represented by the instance is present. If not it will generate an error

```
# sample input:
#   name: firstvpc
#   allow_inbound: ['ssh','https']

# will do nothing because nothing is wrong
g('name').isRequired()

# will generate an error and stops the execution of the chain
g('something_else').isRequired()
```

### .isOptional()

Like required it will do a check if the property represented by the instance is present.
But if it isn't it will stop the execution of the check/chain and won't process further.

```

```

### .expandWith(matchPattern, remoteIdentifier='name')

If an object-property is supposed to reference the name of another object from the config, expandWith() is suposed to do this automatically if there only exists a single instance of the other object.


```
-- sample all_config --

vpc:
- name: firstvpc
  allow_inbound: ['ssh','https']

address_prefix:
- name: zone01
```

Will check if the local property **vpc** is set, if no and there is only one object of type **vpc** defined, it will set local propertys value of **vpc** to the value of the remote property specified by remoteIdentifier (defaults to 'name')

```
g('vpc').expandWith('vpc[*]')

or

g('vpc').expandWith('vpc[*]', remoteIdentifier='name')

```
This leads to the following result:

```
--- updated object config ---

address_prefix:
- name: zone01
  address_prefix: firstvpc
```


### .mustBeOneOf(matchPattern, remoteIdentifier='name')

will do checks against a query (matchPattern) or a list. 
If matchPattern is not a list it will use matchPattern as a query against the full_config and generate the list this way. The elements that end up in the list will be taken from the remote objects properties specified by **remoteIdentifier** (defaults to 'name').

```
-- sample all_config --

security_rule:
- name: https
  tcp: {port_min: 443, port_max: 443}
- name: ssh
  tcp: {port_min: 22, port_max: 22}
  
vpc:
- name: firstvpc
  allow_inbound: ['ssh','https']

```

```
g('vpc').mustBeOneOf('vpc[*]')

or

g('vpc').expandWith('vpc[*]', remoteIdentifier='name')

```



### .lookupFromProperty(localProperty, generatorName, remotePath, identifierProp='name')

it works a bit like .expandWith() but this time the remote object is referenced by a combination of **localProperty** and **generatorName**.

```
-- sample all_config --

address_prefix:
- name: first_zone_prefix
  zone: eu-de-1
  cidr: 192.168.1.0/24
- name: second_zone_prefix
  zone: eu-de-2
  cidr: 192.168.2.0/24

subnet:
- name: sample-subnet-zone-1
  address_prefix: first_zone_prefix
```
 
```
g('ipv4_cidr_block').lookupFromProperty('address_prefix','address_prefix','cidr') 

```

This leads to the following result:

```
--- updated config ---
...

subnet:
- name: sample-subnet-zone-1
  address_prefix: first_zone_prefix
  ipv4_cidr_block: 192.168.1.0/24
```

## Instance Methods

The functionality from the chainable methods is far from beeing perfect. The internal methods have been made public to be able to implement own logic if required.

Internally [python-benedict](https://github.com/fabiocaccamo/python-benedict) is being used to do the heavy query lifting. Therefore the objects returned by **.getFullConfig()** and **getExpandedAttributes()** are benedict instances and provide [all the methods](https://github.com/fabiocaccamo/python-benedict#api) provided by the benedict lib.

### g.appendError(type='error', path=None, msg=None)


```
if(g('localProp')=='foo'):
	g.appendError(msg="localProp shouldn't equal 'foo'")
```

### g.getFullConfig()

returns a queryable version of the all_config object that was initially passed to the instance.

```
all_config = g.getFullConfig()

if len( all_config.match('vpc[*]') ) == 0:
	g.appendError(msg="There are no VPCs defined")
```


