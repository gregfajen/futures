# Futures

A simple, Swifty Futures library for simplifying asynchronous code in Swift.

This repo uses Swift Package Manager: you can open it in Xcode by double-clicking on `Package.swift`.

## Usage/Examples

```swift
import Futures

/// create a future from a traditional completion
func getFutureTree() -> Future<🌲> {
    let promise = Promise<🌲>(on: .background)
    
    let seedling = 🌱()
    seedling.whenTree(promise.succeed)
    
    return promise.future
}


/// create a future from an existng future
func getDecoratedTree() -> Future<🎄> {
    getFutureTree()
        .map(\.decorated) // once we have a future, we use `map` and `flatMap` to create new futures
        .hop(to: .main) // ensure that callbacks occur on the main thread
}

class 🌱 {
    
    func whenGrown(_ completion: (🌲) -> ()) { /* ... */ }
    
}

class 🌲 {
    
    var decorated: 🎄 { /* ... */ }
    
}

class 🎄 {
    
}
```

## Motivation

Futures are a common, easy-to-use async primitive on a variety of platforms. Swift/Objective-C projects typically use Grand Central Dispatch for async, but this can sometimes result what is commonly referred to as ‘callback hell,’ an unfortunate condition where all code slowly begins to resemble JavaScript.

By wrapping these closures in `Future`s and `Promise`s (essentially ‘de-functionalizing’ them), we get full access to Swift features such as methods, computed properties, extensions, and error handling, which lets us greatly simplify our code and improve readability.

Futures also can help simplify threading and concurrency for less-experienced developers: for example, we can ensure tha public calls to our backend API always return on the main thread while internally doing caching on a dedicated database thread.

## The Before and After

Some code has been changed to protect the innocent.

### Before
```swift
func getChatBefore(chatId: Int, completion: @escaping ([String:Any]?, Error?) -> ()) {
    self.apiCall(forPath: "api/v1/chats/\(chatId)/", httpMethod: "GET") { (response, error) in
        guard error == nil, let response = response as? [String:Any] else {
            completion(nil, error ?? ServerError(501)); return
        }
        if let chat = RChatSerializer.deserialize(response) {
            completion(chat, nil)
        } else {
            completion(nil, ParseError())
        }
    }
}
```

### After
```swift
func getChatAfter(_ chatID: Int) -> Future<Chat> {
    API.chats.appending(chatID)
        .get()
        .decoding(API.Chat.self)
        .flatMap(cache)
        .hop(to: .main)
}

func cache(_ chat: API.Chat) -> Future<Chat> { /* ... */ }
```

### Changes/Discussion

The before code could have been greatly simplified just by using Swift’s `Result` type. It also probably should not be fabricating a 501 error that the server wasn't actually returning.

The after code: 
1. sets up an endpoint to call
2. GETs that endpoint, returning a `Future<API.Response>`
3. decodes an internal `API.Chat`, which conforms to `Codable` and has a 1-to-1 relation with our backend's REST response
4. caches this on a background thread, asynchronously yielding a public `Chat` object (`flatMap` takes a function which returns another `Future`)
5. ensures that all callbacks occur on the main thread

Error handling gets conveniently handled for us: `get()` can return a failed future if there's a connection, server, or authorization error; `decoding()` passes along any parsing errors from `Codable`'s `init(from:)`; and `flatMap()` handles any errors that occurred during caching. If an error occurs at any step of the way, the future terminates early. Notably, no error handling code actually appears at all here: it's all conveniently abstracted away in reusable functions.

Thanks to some handy extensions, tons of code that was previously copied and pasted all over gets nicely abstracted away, preventing bugs, saving effort when modifying code, and improving readability.
 
And perhaps best of all (though not entirely related to futures), tons and tons of `if let`s and `guard let`s just magically disappeared!

With futures, a large codebase I worked on was able to remove hundreds of lines of code, solve numerous threading bugs (some simple, some very tricky), and even improve performance.
