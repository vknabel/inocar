//
//  ViewController.swift
//  Inocar Controller
//
//  Created by Valentin Knabel on 30.09.17.
//  Copyright © 2017 Valentin Knabel. All rights reserved.
//

import UIKit
import RxSwift
import RxBluetoothKit
import CoreBluetooth
import CDJoystick

enum Inocar: String {
  case toyotaYaris = "FFE0"
  case specialTank = "FFE2"
}

enum Action {
  case forward
  case backward
  case left
  case right
  case stop

  private var byte: UInt8 {
    switch self {
    case .forward:
      return 0xff
    case .backward:
      return 0x77
    case .left:
      return 0x7f
    case .right:
      return 0xf7
    case .stop:
      return 0x00
    }
  }

  var data: Data {
    return Data(bytes: [byte])
  }
}

class ViewController: UIViewController {
  @IBOutlet var joystick: CDJoystick!
  let disposeBag = DisposeBag()
  let action = PublishSubject<Action>()
  let inocar = ReplaySubject<Inocar>.create(bufferSize: 1)
  let angle = PublishSubject<Double?>()

  override func viewDidLoad() {
    super.viewDidLoad()
    joystick.trackingHandler = { [weak self] data in
      self?.angle.onNext(data.velocity == .zero
        ? nil
        : Double(data.angle)
      )
    }

    // Do any additional setup after loading the view, typically from a nib.
    let manager = CentralManager(queue: .main)
    let characteristic = inocar.flatMapLatest { inocar -> Observable<Characteristic> in
      let serviceId = CBUUID(string: inocar.rawValue)
      let characteristicId = CBUUID(string: "FFE1")
      let afterPoweredOn = manager.observeState()
        .startWith(manager.state)
        .filter { $0 == .poweredOn }
        .timeout(3.0, scheduler: MainScheduler.asyncInstance)
        .debug("afterPoweredOn", trimOutput: false)
        .take(1)
      return
        afterPoweredOn
        .flatMap { _ in manager.scanForPeripherals(withServices: [serviceId]) }
        .debug("peripherals", trimOutput: false)
          .flatMap { (scanned: ScannedPeripheral) in scanned.peripheral.establishConnection() }
        .debug("connect", trimOutput: false)
        .flatMap { $0.discoverServices([serviceId]) }
        .debug("services", trimOutput: false)
        .flatMap { Observable.from($0) }
        .flatMap { $0.discoverCharacteristics([characteristicId])}
        .debug("characteristics", trimOutput: false)
        .flatMap { Observable.from($0) }
        .shareReplayLatestWhileConnected()
    }

    let joystickAction = angle.map { angle -> Action in
      guard let angle = angle else { return .stop }
      let max = 6.28
      let part = max / 8
      switch angle {
      case 0...part, (max - 0.7 * part)...max:
        return .forward
      case part...(part * 3):
        return .right
      case (part * 3)...(part * 6):
        return .backward
      case (part * 6)...(max - 0.7 * part):
        return .left
      default:
        return .stop
      }
    }

    Observable.merge(
      action.debug("action"),
      joystickAction.distinctUntilChanged()
        .debug("joystickAction")
    )
      .withLatestFrom(characteristic) { (a: $0, c: $1) }
      .flatMap { $0.c.writeValue($0.a.data, type: CBCharacteristicWriteType.withoutResponse) }
      .debug("write", trimOutput: true)
      .retry()
      .subscribe().disposed(by: disposeBag)
  }

  @IBAction func didChangeIno(sender: UISegmentedControl) {
    switch sender.selectedSegmentIndex {
    case 0:
      inocar.onNext(.toyotaYaris)
    case 1:
      inocar.onNext(.specialTank)
    default:
      break;
    }
  }

  @IBAction func forward() {
    action.onNext(.forward)
  }

  @IBAction func backward() {
    action.onNext(.backward)
  }

  @IBAction func left() {
    action.onNext(.left)
  }

  @IBAction func right() {
    action.onNext(.right)
  }

  @IBAction func stop() {
    action.onNext(.stop)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

