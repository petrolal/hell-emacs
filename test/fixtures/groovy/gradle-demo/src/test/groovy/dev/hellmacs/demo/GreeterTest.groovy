package dev.hellmacs.demo

import org.junit.jupiter.api.Test

import static org.junit.jupiter.api.Assertions.assertEquals

class GreeterTest {
    @Test
    void greetsByName() {
        assertEquals('Hello, Ann, from Hellmacs!', new Greeter('Hellmacs').greet('Ann'))
    }
}
