package dev.hellmacs.demo

class App {
    static void main(String[] args) {
        println new Greeter('Hellmacs').greet(args ? args[0] : 'world')
    }
}
