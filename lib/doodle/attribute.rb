class Doodle
  # Attribute is itself a Doodle object that is created by #has and
  # added to the #attributes collection in an object's DoodleInfo
  #
  # It is used to provide a context for defining #must and #from rules
  #
  class DoodleAttribute < Doodle
    # note: using extend with a module causes an infinite loop in 1.9
    # hence the inline

    module ClassMethods
      # rewrite rules for the argument list to #has
      def params_from_args(owner, *args)
        Doodle::Debug.d { [owner, args] }
        key_values, positional_args = args.partition{ |x| x.kind_of?(Hash)}
        params = { }
        if positional_args.size > 0
          name = positional_args.shift
          case name
            # has Person --> has :person, :kind => Person
          when Class
            params[:name] = Utils.snake_case(name.to_s.split(/::/).last)
            params[:kind] = name
          else
            params[:name] = name.to_s.to_sym
          end
        end
        params = key_values.inject(params){ |acc, item| acc.merge(item)}
        #DBG: Doodle::Debug.d { [:has, self, self.class, params] }
        if !params.key?(:name)
          __doodle__.handle_error name, ArgumentError, "#{self.class} must have a name", Doodle::Utils.doodle_caller
          params[:name] = :__ERROR_missing_name__
        else
          # ensure that :name is a symbol
          params[:name] = params[:name].to_sym
        end
        name = params[:name]
        __doodle__.handle_error name, ArgumentError, "#{self.class} has too many arguments", Doodle::Utils.doodle_caller if positional_args.size > 0

        if collector = params.delete(:collect)
          if !params.key?(:using)
            if params.key?(:key)
              params[:using] = KeyedAttribute
            else
              params[:using] = AppendableAttribute
            end
          end
          # this in generic CollectorAttribute class
          # collector from(Hash)

          # TODO: rework this to allow multiple classes and mappings
          #p [:collector, collector]
          # FIXME: collector
          if collector.kind_of?(Hash)
            collector_name, collector_class = collector.to_a[0]
          else
            # FIXME: collector could be array
            # if Capitalized word given, treat as classname
            # and create collector for specific class
            collector_class = collector.to_s
            #p [:collector_klass, collector_klass]
            collector_name = Utils.snake_case(collector_class.split(/::/).last)
            #p [:collector_name, collector_class, collector_name]
            # FIXME: sanitize class name for 1.9 (make this a Utils function)
            collector_class = collector_class.gsub(/#<Class:0x[a-fA-F0-9]+>::/, '')
            if collector_class !~ /^[A-Z]/
              collector_class = nil
            end
            #!p [:collector_klass, collector_klass, params[:init]]
          end

          params[:collector_class] = collector_class
          params[:collector_name] = collector_name
        end
        params[:doodle_owner] = owner
        #p [:params, owner, params]
        params
      end
    end
    extend ClassMethods

    # must define these methods before using them in #has below

    # hack: bump off +validate!+ for Attributes - maybe better way of doing
    # this however, without this, tries to validate Attribute to :kind
    # specified, e.g. if you have
    #
    #   has :date, :kind => Date
    #
    # it will fail because Attribute is not a kind of Date -
    # obviously, I have to think about this some more :S
    #
    # at least, I could hand roll a custom validate! method for Attribute
    #
    def validate!(all = true)
    end

    # has default been defined?
    def default_defined?
      ivar_defined?(:default)
    end

    # has default been defined?
    def init_defined?
      ivar_defined?(:init)
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

    # special case - not an attribute
    define_getter_setter :doodle_owner

    # temporarily fake existence of abstract attribute - later has
    # :abstract overrides this
    def abstract
      @abstract = false
    end

    # temporarily fake existence of readonly attribute
    def readonly
      false
    end

    # name of attribute
    has :name, :kind => Symbol do
      from String do |s|
        s.to_sym
      end
    end

    # default value (can be a block)
    has :default, :default => nil

    # initial value
    has :init, :default => nil

    # documentation
    has :doc, :default => ""

    # don't try to initialize from this class
    remove_method(:abstract) # because we faked it earlier - remove to avoid redefinition warning
    has :abstract, :default => false
    remove_method(:readonly) # because we faked it earlier - remove to avoid redefinition warning
    has :readonly, :default => false
  end
end