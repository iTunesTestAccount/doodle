# doodle
# Copyright (C) 2007 by Sean O'Halpin, 2007-11-24

require 'molic_orderedhash'  # todo[replace this with own (required functions only) version]
require 'pp'

# *doodle* is my attempt at an eco-friendly metaprogramming framework that does not
# have pollute core Ruby objects such as Object, Class and Module.

# While doodle itself is useful for defining classes, my main goal is to
# come up with a useful DSL notation for class definitions which can be
# reused in many contexts.

# Docs at http://doodle.rubyforge.org

# patch 1.8.5 to add instance_variable_defined?
# note: this does not seem to work so well with singletons
if RUBY_VERSION < '1.8.6'
  if !Object.method_defined?(:instance_variable_defined?)
    class Object
      __doodle__inspect = instance_method(:inspect)
      define_method :instance_variable_defined? do |name|
        res = __doodle__inspect.bind(self).call
        rx = /\B#{name}=/
        rv = nil
        if rx =~ res
          rv = true
        else
          rv = false
        end
        #p [:instance_variable_defined, rx, name, self, res, rv, caller[0..2]]
        rv
      end
    end
  end
end

module Doodle
  module Debug
    class << self
      # output result of block if ENV['DEBUG_DOODLE'] set
      def d(&block)
        p(block.call) if ENV['DEBUG_DOODLE']
      end
    end
  end

  # Set of utility functions to avoid changing base classes
  module Utils    
    # Unnest arrays by one level of nesting, e.g. [1, [[2], 3]] => [1, [2], 3].
    def self.flatten_first_level(enum)
      enum.inject([]) {|arr, i| if i.kind_of? Array then arr.push(*i) else arr.push(i) end }
    end
    # from facets/string/case.rb, line 80
    def self.snake_case(camel_cased_word)
      camel_cased_word.gsub(/([A-Z]+)([A-Z])/,'\1_\2').gsub(/([a-z])([A-Z])/,'\1_\2').downcase
    end
  end

  # internal error raised when a default was expected but not found
  class NoDefaultError < Exception
  end
  # raised when a validation rule returns false
  class ValidationError < Exception
  end
  # raised when a validation rule returns false
  class UnknownAttributeError < Exception
  end
  # raised when a conversion fails
  class ConversionError < Exception
  end
  # raised when arg_order called with incorrect arguments
  class InvalidOrderError < Exception
  end

  # provides more direct access to the singleton class and a way to
  # treat Modules and Classes equally in a meta context
  module SelfClass

    # return the 'singleton class' of an object, optionally executing
    # a block argument in the (module/class) context of that object
    def singleton_class(&block)
      sc = (class << self; self; end)
      sc.module_eval(&block) if block_given?
      sc
    end

    # return self if a Module, else the singleton class
    def self_class
      self.kind_of?(Module) ? self : singleton_class
    end
    
    # frankly a hack to allow init options to work for singleton classes
    def class_init(params = {}, &block)
      sc = singleton_class(&block)
      sc.attributes.select{|n, a| a.init_defined? }.each do |n, a|
        send(n, a.init)
      end
      sc
    end
  end

  # provide an alternative inheritance chain that works for singleton
  # classes as well as modules, classes and instances
  module Inherited

    # def supers
    #   supers = []
    #   s = superclass rescue nil
    #   while !s.nil?
    #     supers << s
    #     last_s = s.superclass rescue nil
    #     if last_s == s
    #       last_s = nil
    #     end
    #     s = last_s
    #   end
    #   supers
    # end
    
    # parents returns the set of parent classes of an object.
    # note[this is horribly complicated and kludgy - is there a better way?
    # could do with refactoring]

    # this function is a ~mess~ - refactor!!!
    def parents
      # d { [:parents, self.to_s, defined?(superclass)] }
      klasses = []
      if defined?(superclass)
        klass = superclass
        #p [:klass_superclass, klass]
        if self == superclass
          # d { [:parents, 'self == superclass'] }
          klass = nil
        else
          #p [:klass_singleton_class, klass]
          #p [:parents, 'klass = superclass', self, klass, self.ancestors]
          #
          # fixme[any other way to do this? seems really clunky to have to hack strings]
          #
          # What's this doing? Finding the class of which this is the singleton class
          regexen = [/Class:(?:#<)?([A-Z_][A-Za-z_]+)/, /Class:(([A-Z_][A-Za-z_]+))/]
          regexen.each do |regex|
            if cap = self.to_s.match(regex)
              if cap.captures.size > 0
                k = const_get(cap[1])
                if k.respond_to?(:superclass) && k.superclass.respond_to?(:singleton_class)
                  klasses.unshift k.superclass.singleton_class
                end
              end
              #p [:klass_self_klass, klass]
              #p [:klasses, klasses]
              loop do
                if klass.nil?
                  break
                end
                klasses.unshift klass
                #p [:loop_klasses, klasses]
                if klass == klass.superclass
                  #p [:HERE_HERE_BEFORE, klasses]
                  #break
                  return klasses # oof
                end
                klass = klass.superclass
              end
              #p [:HERE_HERE, klasses]
            else
              #p [:klass_self_klass, klass]
              #p [:klasses, klasses]
              loop do
                if klass.nil?
                  break
                end
                klasses << klass
                #p [:loop_klasses, klasses]
                if klass == klass.superclass
                  break
                end
                klass = klass.superclass
              end
            end
          end
        end
      else
        klass = self.class
        #p [:klass_self_klass, klass]
        #p [:klasses, klasses]
        loop do
          if klass.nil?
            break
          end
          klasses << klass
          #p [:loop_klasses, klasses]
          if klass == klass.superclass
            break
          end
          klass = klass.superclass
        end
      end
      klasses
    end

    # send message to all parents and collect results 
    def collect_inherited(message)
      result = []
      klasses = parents
      #p [:parents, parents]
      # d { [:collect_inherited, :parents, message, klasses] }
      #klasses = self_class.ancestors # this produces quite different behaviour
      klasses.each do |klass|
        #p [:testing, klass]
        if klass.respond_to?(message)
          # d { [:collect_inherited, :responded, message, klass] }
          result.unshift(*klass.send(message))
        else
          break
        end
      end
      result
    end
    private :collect_inherited
  end

  # the intent of embrace is to provide a way to create directives that
  # affect all members of a class 'family' without having to modify
  # Module, Class or Object - in some ways, it's similar to Ara Howard's mixable[http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/197296]
  #
  # this works down to third level <tt>class << self</tt> - in practice, this is
  # perfectly good - it would be great to have a completely general
  # solution but I'm doubt whether the payoff is worth the effort

  module Embrace
    # fake module inheritance chain
    def embrace(other, &block)
      # include in instance method chain
      include other
      #extend other
      sc = class << self; self; end
      sc.class_eval {
        # class method chain
        include other
        # singleton method chain
        extend other
        # ensure that subclasses are also embraced
        define_method :inherited do |klass|
          #p [:embrace, :inherited, klass]
          klass.send(:embrace, other)       # n.b. closure
          klass.send(:include, Factory)     # is there another way to do this? i.e. not in embrace
          super(klass) if defined?(super)
        end
      }
      sc.class_eval(&block) if block_given?
    end
  end

  # Lazy is a Proc that caches the result of a call
  class Lazy < Proc
    # return the result of +call+ing this Proc - cached after first +call+
    def value
      @value ||= call
    end
  end

  # A Validation represents a validation rule applied to the instance
  # after initialization. Generated using the Doodle::BaseMethods#must directive.
  class Validation
    attr_accessor :message
    attr_accessor :block
    # create a new validation rule. This is typically a result of
    # calling +must+ so the text should work following the word
    # "must", e.g. "must not be nil", "must be >= 10", etc.
    def initialize(message = 'not be nil', &block)
      @message = message
      @block = block_given? ? block : proc { |x| !self.nil? }
    end
  end

  class DoodleInfo
    DOODLES = {}
    @@raise_exception_on_error = true
    attr_accessor :local_attributes
    attr_accessor :local_validations
    attr_accessor :local_conversions
    attr_accessor :validation_on
    attr_accessor :arg_order
    attr_accessor :errors

    def self.raise_exception_on_error
      @@raise_exception_on_error
    end
    def self.raise_exception_on_error=(tf)
      @@raise_exception_on_error = tf
    end
    
    def initialize(object)
      @local_attributes = OrderedHash.new
      @local_validations = []
      @validation_on = true
      @local_conversions = {}
      @arg_order = []
      @errors = []

      oid = object.object_id
      ObjectSpace.define_finalizer(object) do
        # this seems to be called only on exit
        Doodle::Debug.d { "finalizing #{oid}" }
        DOODLES.delete(oid)
      end
    end
  end

  # the core module of Doodle - to get most facilities provided by Doodle
  # without inheriting from Doodle::Base, include Doodle::Helper, not this module
  module BaseMethods
    include SelfClass
    include Inherited

    # this is the only way to get at internal values
    # FIXME: this is going to leak memory (I think)
    
    def __doodle__
      DoodleInfo::DOODLES[object_id] ||= DoodleInfo.new(self)
    end
    private :__doodle__

    # where should I put this?
    def errors
      # @errors ||= []
      __doodle__.errors
    end
  
    def clear_errors
      #pp [:clear_errors, self, caller]
      # remove_instance_variable("@errors")
      __doodle__.errors.clear
    end
    
    # handle errors either by collecting in :errors or raising an exception
    def handle_error(name, *args)
      #__doodle__.errors << [name, *args]
      #pp [:caller, self, caller]
      #pp [:handle_error, name, args]
      # don't include duplicates (FIXME: hacky - shouldn't have duplicates in the first place)
      if !self.errors.include?([name, *args])
        self.errors << [name, *args]
      end
      if DoodleInfo.raise_exception_on_error
        raise(*args)
      end
    end

    # return attributes defined in instance
    def local_attributes
      __doodle__.local_attributes
    end
    protected :local_attributes

    # returns array of Attributes
    # - if tf == true, returns all inherited attributes
    # - if tf == false, returns only those attributes defined in the current object/class
    def attributes(tf = true)
      if tf
        a = collect_inherited(:local_attributes).inject(OrderedHash.new){ |hash, item|
          #p [:hash, hash, :item, item]
          hash.merge(OrderedHash[*item])
        }.merge(local_attributes)
        # d { [:attributes, self.to_s, a] }
        a
      else
        local_attributes
      end
    end

    # the set of validations defined in the current class (i.e. without inheritance)
    def local_validations
      __doodle__.local_validations
    end
    protected :local_validations

    # returns array of Validations
    # - if tf == true, returns all inherited validations
    # - if tf == false, returns only those validations defined in the current object/class
    def validations(tf = true)
      if tf
        #p [:inherited_validations, collect_inherited(:local_validations)]
        #p [:local_validations, local_validations]
        local_validations + collect_inherited(:local_validations)
      else
        local_validations
      end
    end

    # the set of conversions defined in the current class (i.e. without inheritance)
    def local_conversions
      __doodle__.local_conversions
    end
    protected :local_conversions

    # returns array of conversions
    # - if tf == true, returns all inherited conversions
    # - if tf == false, returns only those conversions defined in the current object/class
    def conversions(tf = true)
      if tf
        a = collect_inherited(:local_conversions).inject(OrderedHash.new){ |hash, item|
          #p [:hash, hash, :item, item]
          hash.merge(OrderedHash[*item])
        }.merge(self.local_conversions)
        # d { [:conversions, self.to_s, a] }
        a
      else
        local_conversions
      end
    end

    # lookup a single attribute by name, searching the singleton class first
    def lookup_attribute(name)
      # (look at singleton attributes first)
      # fixme[this smells like a hack to me - why not handled in attributes?]
      singleton_class.attributes[name] || attributes[name]
    end
    private :lookup_attribute

    # either get an attribute value (if no args given) or set it
    # (using args and/or block)
    def getter_setter(name, *args, &block)
      # d { [:getter_setter, name, args, block] }
      name = name.to_sym
      if block_given? || args.size > 0
        # setter
        _setter(name, *args, &block)
      else
        _getter(name)
      end
    end
    private :getter_setter

    # get an attribute by name - return default if not otherwise defined
    def _getter(name, &block)
      ## d { [:_getter, 1, self.to_s, name, block, instance_variables] }
      # getter
      ivar = "@#{name}"
      if instance_variable_defined?(ivar)
        ## d { [:_getter, 2, name, block] }
        v = instance_variable_get(ivar)
        #d { [:_getter, :defined, name, v] }
        #         if v.kind_of?(Lazy)
        #          p [name, self, self.class, v]
        #          v = instance_eval &v.block
        #         end
        v
      else
        # handle default
        # Note: use :init => value to cover cases where defaults don't work
        # (e.g. arrays that disappear when you go out of scope)
        att = lookup_attribute(name)
        #d { [:getter, name, att, block] }
        if att.default_defined?
          if att.default.kind_of?(Proc)
            instance_eval(&att.default)
          else
            att.default
          end
        else
          # This is an internal error (i.e. shouldn't happen)
          handle_error name, NoDefaultError, "Internal error - '#{name}' has no default defined", [caller[-1]]
        end
      end
    end
    private :_getter

    # set an attribute by name - apply validation if defined
    def _setter(name, *args, &block)
      #pp [:_setter, self, self.class,  name, args, block]
      ivar = "@#{name}"
      args.unshift(block) if block_given?
      # d { [:_setter, 3, :setting,  name, ivar, args] }
      att = lookup_attribute(name)
      # d { [:_setter, 4, :setting,  name, att] }
      if att
        #d { [:_setter, :instance_variable_set, :ivar, ivar, :args, args, :att_validate, att.validate(*args) ] }
        v = instance_variable_set(ivar, att.validate(self, *args))
      else
        #d { [:_setter, :instance_variable_set, ivar, args ] }
        v = instance_variable_set(ivar, *args)
      end
      validate!(false)
      v
    end
    private :_setter

    # if block passed, define a conversion from class
    # if no args, apply conversion to arguments
    def from(*args, &block)
      # d { [:from, self, self.class, self.name, args, block] }
      if block_given?
        # set the rule for each arg given
        args.each do |arg|
          local_conversions[arg] = block
        end
        # d { [:from, conversions] }
      else
        convert(self, *args)
      end
    end

    # add a validation
    def must(message = 'be valid', &block)
      local_validations << Validation.new(message, &block)
    end

    # add a validation that attribute must be of class <= kind
    def kind(*args, &block)
      # d { [:kind, args, block] }
      if args.size > 0
        # todo[figure out how to handle kind being specified twice?]
        @kind = args.first
        local_validations << (Validation.new("be #{@kind}") { |x| x.class <= @kind })
      else
        @kind
      end
    end

    # convert a value according to conversion rules
    def convert(owner, value)
      begin
        if (converter = conversions[value.class])
          value = converter[value]
        else
          # try to find nearest ancestor
          ancestors = value.class.ancestors
          matches = ancestors & conversions.keys
          indexed_matches = matches.map{ |x| ancestors.index(x)}
          #p [matches, indexed_matches, indexed_matches.min]
          if indexed_matches.size > 0
            converter_class = ancestors[indexed_matches.min]
            #p [:converter, converter_class]
            if converter = conversions[converter_class]
              value = converter[value]
            end
          end
        end
      rescue => e
        owner.handle_error name, ConversionError, e.to_s, [caller[-1]]
      end
      value
    end

    # validate that args meet rules defined with +must+
    def validate(owner, *args)
      value = convert(owner, *args)
      #d { [:validate, self, :args, args, :value, value ] }
      validations.each do |v|
        Doodle::Debug.d { [:validate, self, v, args, value] }
        if !v.block[value]
          owner.handle_error name, ValidationError, "#{ name } must #{ v.message } - got #{ value.class }(#{ value.inspect })", [caller[-1]]
        end
      end
      #d { [:validate, :value, value ] }
      value
    end
    
    # define a getter_setter
    def define_getter_setter(name, *args, &block)      
      # d { [:define_getter_setter, [self, self.class, self_class], name, args, block] }

      # need to use string eval because passing block
      module_eval "def #{name}(*args, &block); getter_setter(:#{name}, *args, &block); end"
      module_eval "def #{name}=(*args, &block); _setter(:#{name}, *args); end"
    end
    private :define_getter_setter

    # define a collector
    # - collection should provide a :<< method
    def define_collector(collection, name, klass = nil, &block)
      # need to use string eval because passing block
      if klass.nil?
        module_eval "def #{name}(*args, &block); args.unshift(block) if block_given?; #{collection}.<<(*args); end"
      else
        module_eval "def #{name}(*args, &block); #{collection} << #{klass}.new(*args, &block); end"
      end
    end
    private :define_collector

    # +has+ is an extended +attr_accessor+
    #
    # simple usage - just like +attr_accessor+:
    #
    #  class Event
    #    has :date
    #  end
    #
    # set default value:
    #
    #  class Event
    #    has :date, :default => Date.today
    #  end
    #
    # set lazily evaluated default value:
    #
    #  class Event
    #    has :date do
    #      default { Date.today }
    #    end
    #  end
    #    
    def has(*args, &block)
      Doodle::Debug.d { [:has, self, self.class, self_class, args] }
      name = args.shift.to_sym
      # d { [:has2, name, args] }
      key_values, positional_args = args.partition{ |x| x.kind_of?(Hash)}
      handle_error name, ArgumentError, "Too many arguments" if positional_args.size > 0
      # d { [:has_args, self, key_values, positional_args, args] }
      params = { :name => name }
      params = key_values.inject(params){ |acc, item| acc.merge(item)}

      # don't pass collector params through to Attribute
      if collector = params.delete(:collect)
        if collector.kind_of?(Hash)
          collector_name, klass = collector.to_a[0]
        else
          # if Capitalized word given, treat as classname
          # and create collector for specific class
          klass = collector.to_s
          collector_name = Utils.snake_case(klass)
          if klass !~ /^[A-Z]/
            klass = nil
          end
        end
        define_collector name, collector_name, klass
      end
      
      # d { [:has_args, :params, params] }
      # define getter setter before setting up attribute
      define_getter_setter name, *args, &block
      local_attributes[name] = attribute = Attribute.new(params, &block)        
      attribute
    end

    # define order for positional arguments
    def arg_order(*args)
      if args.size > 0
        begin
          #p [:arg_order, 1, self, self.class, args]
          args.uniq!
          args.each do |x|
            handle_error :arg_order, ArgumentError, "#{x} not a Symbol" if !(x.class <= Symbol)
            handle_error :arg_order, NameError, "#{x} not an attribute name" if !attributes.keys.include?(x)
          end
          __doodle__.arg_order = args
        rescue Exception => e
          #p [InvalidOrderError, e.to_s]
          handle_error :arg_order, InvalidOrderError, e.to_s, [caller[-1]]
        end
      else
        #p [:arg_order, 3, self, self.class, :default]
        __doodle__.arg_order + (attributes.keys - __doodle__.arg_order)
      end
    end

    # helper function to initialize from hash - this is safe to use
    # after initialization (validate! is called if this method is
    # called after initialization)
    def initialize_from_hash(*args)
      defer_validation do
        # hash initializer
        # separate into array of hashes of form [{:k1 => v1}, {:k2 => v2}] and positional args 
        key_values, args = args.partition{ |x| x.kind_of?(Hash)}
        Doodle::Debug.d { [:initialize_from_hash, :key_values, key_values, :args, args] }

        # match up positional args with attribute names (from arg_order) using idiom to create hash from array of assocs
        arg_keywords = Hash[*(Utils.flatten_first_level(self.class.arg_order[0...args.size].zip(args)))]
        # d { [:initialize, :arg_keywords, arg_keywords] }

        # set up initial values with ~clones~ of specified values (so not shared between instances)
        init_values = attributes.select{|n, a| a.init_defined? }.inject({}) {|hash, (n, a)| 
          hash[n] = begin
            case a.init
            when NilClass, TrueClass, FalseClass, Fixnum
              a.init
            else
              a.init.clone 
            end
          rescue 
            a.init
          end
          ; hash }

        # add to start of key_values array (so can be overridden by params)
        key_values.unshift(init_values)

        # merge all hash args into one
        key_values = key_values.inject(arg_keywords) { |hash, item| hash.merge(item)}

        # convert key names to symbols
        key_values = key_values.inject({}) {|h, (k, v)| h[k.to_sym] = v; h}
        Doodle::Debug.d { [:initialize_from_hash, :key_values2, key_values, :args2, args] }
        
        # create attributes
        key_values.keys.each do |key|
          Doodle::Debug.d { [:initialize_from_hash, :setting, key, key_values[key]] }
          if respond_to?(key)
            send(key, key_values[key])
          else
            # raise error if not defined
            handle_error key, Doodle::UnknownAttributeError, "Unknown attribute '#{key}' #{key_values[key].inspect}"
          end
        end
      end
    end
    #private :initialize_from_hash

    # return true if instance variable +name+ defined
    def ivar_defined?(name)
      instance_variable_defined?("@#{name}")
    end
    private :ivar_defined?

    # validate this object by applying all validations in sequence
    # - if all == true, validate all attributes, e.g. when loaded from YAML, else validate at object level only
    def validate!(all = true)
      #pp [:validate!, all, caller]
      if all
        clear_errors
      end
      #Doodle::Debug.d { [:validate!, self] }
      #Doodle::Debug.d { [:validate!, self, __doodle__.validation_on] }
      if __doodle__.validation_on
        attributes.each do |name, att|
          # treat default as special case
          if att.name == :default || att.default_defined?
            # nop
          elsif !ivar_defined?(att.name)
            handle_error name, Doodle::ValidationError, "#{self} missing required attribute '#{name}'", [caller[-1]]
          end
          # if all == true, reset values so conversions and validations are applied to raw instance variables
          # e.g. when loaded from YAML
          att_name = "@#{att.name}"
          if all && instance_variable_defined?(att_name)
            send(att.name, instance_variable_get(att_name))
          end
        end
        # now apply instance level validations
        validations.each do |v|
          Doodle::Debug.d { [:validate!, self, v ] }
          if !instance_eval(&v.block)
            handle_error :validate!, ValidationError, "#{ self.inspect } must #{ v.message }", [caller[-1]]
          end
        end
      end
      # if OK, then return self
      self
    end

    # turn off validation, execute block, then set validation to same
    # state as it was before +defer_validation+ was called - can be nested
    def defer_validation(&block)
      old_validation = __doodle__.validation_on
      __doodle__.validation_on = false
      v = nil
      begin
        v = instance_eval(&block)
      ensure
        __doodle__.validation_on = old_validation
      end
      validate!(false)
      v
    end

    # object can be initialized from a mixture of positional arguments,
    # hash of keyword value pairs and a block which is instance_eval'd
    def initialize(*args, &block)
      __doodle__.validation_on = true
      
      defer_validation do
        # d { [:initialize, self.to_s, args, block] }
        initialize_from_hash(*args)
        # d { [:initialize, self.to_s, args, block, :calling_block] }
        instance_eval(&block) if block_given?
      end
    end

  end

  # A factory function is a function that has the same name as
  # a class which acts just like class.new. For example:
  #   Cat(:name => 'Ren')
  # is the same as:
  #   Cat.new(:name => 'Ren')
  # As the notion of a factory function is somewhat contentious [xref
  # ruby-talk], you need to explicitly ask for them by including Factory
  # in your base class:
  #   class Base < Doodle::Root
  #     include Factory
  #   end
  #   class Dog < Base
  #   end
  #   stimpy = Dog(:name => 'Stimpy')
  # etc.
  module Factory
    RX_IDENTIFIER = /[A-Za-z_][A-Za-z_0-9]+\??/
    class << self   
      # create a factory function in appropriate module for the specified class
      def factory(konst)
        #p [:factory, name]
        name = konst.to_s
        names = name.split(/::/)
        name = names.pop
        if names.empty?
          # top level class - should be available to all
          klass = Object
          #p [:names_empty, klass, mklass]
          if !klass.respond_to?(name) && name =~ Factory::RX_IDENTIFIER
            eval src = "def #{ name }(*args, &block); ::#{name}.new(*args, &block); end", ::TOPLEVEL_BINDING
          end
        else
          klass = names.inject(self) {|c, n| c.const_get(n)}
          mklass = class << klass; self; end
          #p [:names, klass, mklass]
          #eval src = "def #{ names.join('::') }::#{name}(*args, &block); #{ names.join('::') }::#{name}.new(*args, &block); end"
          # TODO: check how many times this is being called
          if !klass.respond_to?(name) && name =~ Factory::RX_IDENTIFIER
            klass.class_eval(src = "def self.#{name}(*args, &block); #{name}.new(*args, &block); end")
          end
        end
        #p [:factory, mklass, klass, src]
      end

      # inherit the factory function capability
      def included(other)
        #p [:factory, :included, self, other ]
        super
        #raise Exception, "#{self} can only be included in a Class" if !other.kind_of? Class
        # make +factory+ method available
        factory other
      end
    end
  end

  # Include Doodle::Helper if you want to derive from another class
  # but still get Doodle goodness in your class (including Factory
  # methods).
  module Helper
    def self.included(other)
      #p [:Helper, :included, self, other ]
      super
      other.module_eval {
        extend Embrace
        embrace BaseMethods
        include Factory
      }
    end
  end

  # derive from Base if you want all the Doodle goodness
  class Base
    include Helper
  end

  # todo[need to extend this]
  class Attribute < Doodle::Base
    # must define these methods before using them in #has below

    # bump off +validate!+ for Attributes - maybe better way of doing
    # this however, without this, tries to validate Attribute to :kind
    # specified, e.g. if you have
    #
    #   has :date, :kind => Date
    #
    # it will fail because Attribute is not a kind of Date -
    # obviously, I have to think about this some more :S
    #
    def validate!(all = true)
    end

    # is this attribute optional? true if it has a default defined for it
    def optional?
      default_defined? or init_defined?
    end

    # an attribute is required if it has no default or initial value defined for it
    def required?
      # d { [:default?, self.class, self.name, instance_variable_defined?("@default"), @default] }
      !optional?
    end

    # has default been defined?
    def default_defined?
      ivar_defined?(:default)
    end
    # has default been defined?
    def init_defined?
      ivar_defined?(:init)
    end

    # name of attribute
    has :name, :kind => Symbol do
      from String do |s|
        s.to_sym
      end
    end
    # default value (can be a block)
    has :default, :default => nil
    # initial value
    has :init, :default => nil

  end
end

############################################################
# and we're bootstrapped! :)
############################################################
