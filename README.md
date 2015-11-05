# Reactive Record

#### reactive-record gives you active-record models on the client integrated with react.rb.

*"So simple its almost magic" (Amazed developer)*

You do nothing to your current active-record models except move them to the views/models directory (so they are compiled on the client as well as the server.)

* Fully integrated with [React.rb](https://github.com/zetachang/react.rb/wiki) (which is React with a beautiful ruby dsl.)
* Takes advantage of React prerendering, and afterwards additional data is *lazy loaded* as it is needed by the client.
* Supports full CRUD access using standard Active Record features, including associations, aggregations, and errors.
* Uses [Hobo](http://www.hobocentral.net/manual/permissions) style model based permission mechanism for security.
* Models and even methods within models can be selectively implemented "server-side" only.

There are no docs yet, but you may consider the test cases as a starting point, or have a look at [react.rb todo](https://reactiverb-todo.herokuapp.com/) (live demo [here.](https://reactiverb-todo.herokuapp.com/))

Head on over to https://gitter.im/zetachang/react.rb to ask any questions you might have!
