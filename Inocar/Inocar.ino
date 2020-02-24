// #define ESP 1

#ifdef ESP
#define PIN0 20
#define PIN1 19
#define PIN2 18
#define PIN3 17
#define SERIAL_WRITE 9 // TODO
#define SERIAL_READ 8 // TODO
#else
#define PIN0 5
#define PIN1 6
#define PIN2 10
#define PIN3 11
#define SERIAL_WRITE 9
#define SERIAL_READ 8
#endif

#include <SoftwareSerial.h>

SoftwareSerial softSerial(SERIAL_READ, SERIAL_WRITE);

void setup() {
  Serial.begin(9600);
  softSerial.begin(9600);
  // put your setup code here, to run once:
  pinMode(PIN0, OUTPUT);
  pinMode(PIN1, OUTPUT);
  pinMode(PIN2, OUTPUT);
  pinMode(PIN3, OUTPUT);
}

const int forwardLeft = 0x1;
const int forwardRight = 0x4;
const int backwardLeft = 0x2;
const int backwardRight = 0x8;

const int stay = 0;
const int forward = forwardLeft | forwardRight; // 5
const int backward = backwardLeft | backwardRight; // 10
const int turnLeft = backwardLeft | forwardRight; // 6
const int turnRight = forwardLeft | backwardRight; // 9

void loop() {
  //read from the Serial and print to the HM-10
  //if(Serial.available()) {
  //  softSerial.write(Serial.read());
  //}
  //if(softSerial.available()) {
  //  Serial.write(softSerial.read());
  //}
   
  //read from the HM-10 and print in the Serial
  if(softSerial.available()) {
    byte rawInput = softSerial.read();
    Serial.print("left ");
    Serial.print(rawInput &0xF, HEX);
    Serial.print("right ");
    Serial.println(rawInput >> 4, HEX);
    driveTires(rawInput & 0xF, PIN0, PIN1);
    driveTires(rawInput >> 4, PIN2, PIN3);
    delay(100);
  }
}

void driveTires(byte rawInput, int forwardPin, int backwardPin) {
  bool isForward = directionFromByte(rawInput);
  byte velocity = velocityFromByte(rawInput);
  Serial.println(isForward ? "f" : "b");
  accelerateTire(velocity, isForward ? forwardPin : backwardPin);
  stopTire(!isForward ? forwardPin : backwardPin);
}

void accelerateTire(byte velocity, int pin) {
  analogWrite(pin, velocity);
}

void stopTire(int pin) {
  analogWrite(pin, 0);
}

bool directionFromByte(byte rawInput) {
  Serial.print(rawInput, HEX);
  Serial.print(", ");
  Serial.print(rawInput & 0x8, HEX);
  Serial.print(" => ");
  Serial.println((rawInput & 0x8) > 0, HEX);
  return (rawInput & 0x8) > 0;
}

byte velocityFromByte(byte rawInput) {
  return (byte)((int)(rawInput & 0x7) * 0xFF / 0x7);
}

