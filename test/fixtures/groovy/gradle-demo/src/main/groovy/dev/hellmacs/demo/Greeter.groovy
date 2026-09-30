package dev.hellmacs.demo

/** A plain class: completion, navigation and diagnostics targets. */
class Greeter {
    final String from

    Greeter(String from) {
        this.from = from
    }

    String greet(String name) {
        "Hello, ${name}, from ${from}!"
    }
}
