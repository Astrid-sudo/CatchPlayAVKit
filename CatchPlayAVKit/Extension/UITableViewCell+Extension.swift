//
//  UITableViewCell+Extension.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/5.
//

import UIKit

protocol CellReuseID: ReuseID {}

extension UITableViewCell: CellReuseID {}
extension UITableViewHeaderFooterView: CellReuseID {}

