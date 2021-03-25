# frozen_string_literal: true

module Wannme
  class WannmeObject
    include Enumerable

    # The default :id method is deprecated and isn't useful to us
    undef :id if method_defined?(:id)

    def initialize(id = nil)
      id, @retrieve_params = Util.normalize_id(id)
      @original_values = {}
      @values = {}
      # This really belongs in APIResource, but not putting it there allows us
      # to have a unified inspect method
      @unsaved_values = Set.new
      @transient_values = Set.new
      @values[:id] = id if id
    end

    def self.construct_from(values)
      values = Wannme::Util.symbolize_names(values)

      # work around protected #initialize_from for now
      new(values[:id]).send(:initialize_from, values)
    end

    # Determines the equality of two Wannme objects. Wannme objects are
    # considered to be equal if they have the same set of values and each one
    # of those values is the same.
    def ==(other)
      other.is_a?(WannmeObject) && @values == other.instance_variable_get(:@values)
    end

    # Hash equality. As with `#==`, we consider two equivalent Wannme objects
    # equal.
    def eql?(other)
      # Defer to the implementation on `#==`.
      self == other
    end

    # As with equality in `#==` and `#eql?`, we hash two Wannme objects to the
    # same value if they're equivalent objects.
    def hash
      @values.hash
    end

    def to_s(*_args)
      JSON.pretty_generate(to_hash)
    end

    def inspect
      id_string = respond_to?(:id) && !id.nil? ? " id=#{id}" : ''
      "#<#{self.class}:0x#{object_id.to_s(16)}#{id_string}> JSON: " +
        JSON.pretty_generate(@values)
    end

    # Mass assigns attributes on the model.
    #
    # This is a version of +update_attributes+ that takes some extra options
    # for internal use.
    #
    # ==== Attributes
    #
    # * +values+ - Hash of values to use to update the current attributes of
    #   the object. If you are on ruby 2.7 or higher make sure to wrap in curly
    #   braces to be ruby 3 compatible.
    def update_attributes(values)
      values.each do |k, v|
        add_accessors([k], values) unless metaclass.method_defined?(k.to_sym)
        @values[k] = Util.convert_to_wannme_object(v)
        @unsaved_values.add(k)
      end
    end

    def [](key)
      @values[key.to_sym]
    end

    def []=(key, value)
      send(:"#{key}=", value)
    end

    def keys
      @values.keys
    end

    def values
      @values.values
    end

    def to_json(*_opts)
      # TODO: pass opts to JSON.generate?
      JSON.generate(@values)
    end

    def as_json(*opts)
      @values.as_json(*opts)
    end

    def to_hash
      maybe_to_hash = lambda do |value|
        return nil if value.nil?

        value.respond_to?(:to_hash) ? value.to_hash : value
      end

      @values.each_with_object({}) do |(key, value), acc|
        acc[key] = case value
                   when Array
                     value.map(&maybe_to_hash)
                   else
                     maybe_to_hash.call(value)
                   end
      end
    end

    def each(&blk)
      @values.each(&blk)
    end

    def serialize_params(options = {})
      update_hash = {}

      @values.each do |k, v|
        # There are a few reasons that we may want to add in a parameter for
        # update:
        #
        #   1. The `force` option has been set.
        #   2. We know that it was modified.
        #   3. Its value is a WannmeObject. A WannmeObject may contain modified
        #      values within in that its parent WannmeObject doesn't know about.
        #
        unsaved = @unsaved_values.include?(k)
        next unless options[:force] || unsaved || v.is_a?(WannmeObject)

        update_hash[k.to_sym] = serialize_params_value(
          @values[k], @original_values[k], unsaved, options[:force], key: k
        )
      end

      # a `nil` that makes it out of `#serialize_params_value` signals an empty
      # value that we shouldn't appear in the serialized form of the object
      update_hash.reject! { |_, v| v.nil? }

      update_hash
    end

    protected def metaclass
      class << self; self; end
    end

    protected def remove_accessors(keys)
      metaclass.instance_eval do
        keys.each do |k|
          # Remove methods for the accessor's reader and writer.
          [k, :"#{k}=", :"#{k}?"].each do |method_name|
            next unless method_defined?(method_name)

            begin
              remove_method(method_name)
            rescue NameError
              # In some cases there can be a method that's detected with
              # `method_defined?`, but which cannot be removed with
              # `remove_method`, even though it's on the same class. The only
              # case so far that we've noticed this is when a class is
              # reopened for monkey patching:
              #
              #     https://github.com/stripe/stripe-ruby/issues/749
              #
              # Here we swallow that error and issue a warning so at least
              # the program doesn't crash.
              warn("WARNING: Unable to remove method `#{method_name}`; " \
                "if custom, please consider renaming to a name that doesn't " \
                'collide with an API property name.')
            end
          end
        end
      end
    end

    protected def add_accessors(keys, values)
      metaclass.instance_eval do
        keys.each do |k|
          if k == :method
            # Object#method is a built-in Ruby method that accepts a symbol
            # and returns the corresponding Method object. Because the API may
            # also use `method` as a field name, we check the arity of *args
            # to decide whether to act as a getter or call the parent method.
            define_method(k) { |*args| args.empty? ? @values[k] : super(*args) }
          else
            define_method(k) { @values[k] }
          end

          define_method(:"#{k}=") do |v|
            if v == ''
              raise ArgumentError, "You cannot set #{k} to an empty string. " \
                'We interpret empty strings as nil in requests. ' \
                "You may set (object).#{k} = nil to delete the property."
            end
            @values[k] = Util.convert_to_wannme_object(v)
            @unsaved_values.add(k)
          end

          define_method(:"#{k}?") { @values[k] } if [FalseClass, TrueClass].include?(values[k].class)
        end
      end
    end

    # Disabling the cop because it's confused by the fact that the methods are
    # protected, but we do define `#respond_to_missing?` just below. Hopefully
    # this is fixed in more recent Rubocop versions.
    protected def method_missing(name, *args)
      # TODO: only allow setting in updateable classes.
      if name.to_s.end_with?('=')
        attr = name.to_s[0...-1].to_sym

        # Pull out the assigned value. This is only used in the case of a
        # boolean value to add a question mark accessor (i.e. `foo?`) for
        # convenience.
        val = args.first

        # the second argument is only required when adding boolean accessors
        add_accessors([attr], attr => val)

        begin
          mth = method(name)
        rescue NameError
          raise NoMethodError,
                "Cannot set #{attr} on this object. HINT: you can't set: " \
                "#{@@permanent_attributes.to_a.join(', ')}"
        end
        return mth.call(args[0])
      elsif @values.key?(name)
        return @values[name]
      end

      begin
        super
      rescue NoMethodError => e
        # If we notice the accessed name of our set of transient values we can
        # give the user a slightly more helpful error message. If not, just
        # raise right away.
        raise unless @transient_values.include?(name)

        raise NoMethodError,
              e.message + ".  HINT: The '#{name}' attribute was set in the " \
              'past, however.  It was then wiped when refreshing the object ' \
              "with the result returned by Wannme's API, probably as a " \
              'result of a save().  The attributes currently available on ' \
              "this object are: #{@values.keys.join(', ')}"
      end
    end
    protected def respond_to_missing?(symbol, include_private = false)
      @values && @values.key?(symbol) || super
    end

    # Re-initializes the object based on a hash of values (usually one that's
    # come back from an API call). Adds or removes value accessors as necessary
    # and updates the state of internal data.
    #
    # Protected on purpose! Please do not expose.
    #
    # ==== Options
    #
    # * +:values:+ Hash used to update accessors and values.
    # * +:partial:+ Indicates that the re-initialization should not attempt to
    #   remove accessors.
    protected def initialize_from(values, partial = false)
      # the `#send` is here so that we can keep this method private
      @original_values = self.class.send(:deep_copy, values)

      removed = partial ? Set.new : Set.new(@values.keys - values.keys)
      added = Set.new(values.keys - @values.keys)

      # Wipe old state before setting new.  This is useful for e.g. updating a
      # customer, where there is no persistent card parameter.  Mark those
      # values which don't persist as transient

      remove_accessors(removed)
      add_accessors(added, values)

      removed.each do |k|
        @values.delete(k)
        @transient_values.add(k)
        @unsaved_values.delete(k)
      end

      update_attributes(values)
      values.each_key do |k|
        @transient_values.delete(k)
        @unsaved_values.delete(k)
      end

      self
    end

    protected def serialize_params_value(value, original, unsaved, force,
                                         key: nil)
      if value.nil?
        ''

      # The logic here is that essentially any object embedded in another
      # object that had a `type` is actually an API resource of a different
      # type that's been included in the response. These other resources must
      # be updated from their proper endpoints, and therefore they are not
      # included when serializing even if they've been modified.
      #
      # There are _some_ known exceptions though.
      #
      # For example, if the value is unsaved (meaning the user has set it), and
      # it looks like the API resource is persisted with an ID, then we include
      # the object so that parameters are serialized with a reference to its
      # ID.
      #
      # Another example is that on save API calls it's sometimes desirable to
      # update a customer's default source by setting a new card (or other)
      # object with `#source=` and then saving the customer. The
      # `#save_with_parent` flag to override the default behavior allows us to
      # handle these exceptions.
      #
      # We throw an error if a property was set explicitly but we can't do
      # anything with it because the integration is probably not working as the
      # user intended it to.
      elsif value.is_a?(APIResource) && !value.save_with_parent
        if !unsaved
          nil
        elsif value.respond_to?(:id) && !value.id.nil?
          value
        else
          raise ArgumentError, "Cannot save property `#{key}` containing " \
            "an API resource. It doesn't appear to be persisted and is " \
            'not marked as `save_with_parent`.'
        end

      elsif value.is_a?(Array)
        update = value.map { |v| serialize_params_value(v, nil, true, force) }

        # This prevents an array that's unchanged from being resent.
        update if update != serialize_params_value(original, nil, true, force)

      # Handle a Hash for now, but in the long run we should be able to
      # eliminate all places where hashes are stored as values internally by
      # making sure any time one is set, we convert it to a WannmeObject. This
      # will simplify our model by making data within an object more
      # consistent.
      #
      # For now, you can still run into a hash if someone appends one to an
      # existing array being held by a WannmeObject. This could happen for
      # example by appending a new hash onto `additional_owners` for an
      # account.
      elsif value.is_a?(Hash)
        Util.convert_to_wannme_object(value).serialize_params

      elsif value.is_a?(WannmeObject)
        update = value.serialize_params(force: force)

        # If the entire object was replaced and this is an additive object,
        # then we need blank each field of the old object that held a value
        # because otherwise the update to the keys of the object will be
        # additive instead of a full replacement. The new serialized values
        # will override any of these empty values.
        if original && unsaved && key && self.class.additive_object_param?(key)
          update = empty_values(original).merge(update)
        end

        update

      else
        value
      end
    end

    # Produces a deep copy of the given object including support for arrays,
    # hashes, and WannmeObjects.
    private_class_method def self.deep_copy(obj)
      case obj
      when Array
        obj.map { |e| deep_copy(e) }
      when Hash
        obj.each_with_object({}) do |(k, v), copy|
          copy[k] = deep_copy(v)
          copy
        end
      when WannmeObject
        obj.class.construct_from(
          deep_copy(obj.instance_variable_get(:@values))
        )
      else
        obj
      end
    end

    # Returns a hash of empty values for all the values that are in the given
    # WannmeObject.
    private def empty_values(obj)
      values = case obj
               when Hash         then obj
               when WannmeObject then obj.instance_variable_get(:@values)
               else
                 raise ArgumentError,
                       '#empty_values got unexpected object type: ' \
                       "#{obj.class.name}"
               end

      values.each_with_object({}) do |(k, _), update|
        update[k] = ''
      end
    end
  end
end
