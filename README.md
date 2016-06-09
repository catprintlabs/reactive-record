# Reactive Record

[![Join the chat at https://gitter.im/catprintlabs/reactive-record](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/reactrb/chat?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Code Climate](https://codeclimate.com/github/reactrb/reactive-record/badges/gpa.svg)](https://codeclimate.com/github/reactrb/reactive-record)
[![Gem Version](https://badge.fury.io/rb/reactive-record.svg)](https://badge.fury.io/rb/reactive-record)


#### reactive-record gives you active-record models on the client integrated with reactrb.

*"So simple its almost magic" (Amazed developer)*

#### NOTE: reactive-record >= 0.8.x depends on the reactrb gem.  You must [upgrade to reactrb](https://github.com/reactrb/reactrb#upgrading-to-reactrb) 

You do nothing to your current active-record models except move them to the models/public directory (so they are compiled on the client as well as the server.)

* Fully integrated with [Reactrb](https://github.com/reactrb/reactrb) (which is React with a beautiful ruby dsl.)
* Takes advantage of React prerendering, and afterwards additional data is *lazy loaded* as it is needed by the client.
* Supports full CRUD access using standard Active Record features, including associations, aggregations, and errors.
* Uses model based authorization mechanism for security similar to [Hobo](http://www.hobocentral.net/manual/permissions) or [Pundit](https://github.com/elabs/pundit).
* Models and even methods within models can be selectively implemented "server-side" only.

There are no docs yet, but you may consider the test cases as a starting point, or have a look at [reactrb todo](https://reactiverb-todo.herokuapp.com/) (live demo [here.](https://reactiverb-todo.herokuapp.com/))

For best results simply use the [reactrb-rails-installer](https://github.com/reactrb/reactrb-rails-installer) to install everything you need into a new or existing rails app.

Head on over to [gitter.im](https://gitter.im/reactrb/chat) to ask any questions you might have!

Note: We have dropped suppport for the ability to load the same Class from two different files. If you need this functionality load the following code to your config/application.rb file.

```ruby
module ::ActiveRecord
  module Core
    module ClassMethods
      def inherited(child_class)
        begin
          file = Rails.root.join('app','models',"#{child_class.name.underscore}.rb").to_s rescue nil
          begin
            require file
          rescue LoadError
          end
          # from active record:
          child_class.initialize_find_by_cache
        rescue
        end # if File.exist?(Rails.root.join('app', 'view', 'models.rb'))
        super
      end
    end
  end
end
```
