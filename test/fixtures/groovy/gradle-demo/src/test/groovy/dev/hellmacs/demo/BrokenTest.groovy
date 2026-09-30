package dev.hellmacs.demo

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.condition.EnabledIfSystemProperty

import static org.junit.jupiter.api.Assertions.assertEquals

// Fails on purpose, and only with -Dhellmacs.fail=true: what a failing
// test looks like in the results view and the compilation buffer.
@EnabledIfSystemProperty(named = 'hellmacs.fail', matches = 'true')
class BrokenTest {
    @Test
    void greetsWrongly() {
        assertEquals('Hi, Ann!', new Greeter('Hellmacs').greet('Ann'))
    }
}
