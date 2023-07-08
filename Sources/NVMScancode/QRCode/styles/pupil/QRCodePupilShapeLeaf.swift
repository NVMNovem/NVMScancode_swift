//  MIT License
//
//  Copyright © 2023 Darren Ford. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
//  WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
//  OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import CoreGraphics
import Foundation

// MARK: - Pupil shape

public extension QRCode.PupilShape {
	/// A 'leaf' style pupil design
	@objc(QRCodePupilShapeLeaf) class Leaf: NSObject, QRCodePupilShapeGenerator {
		@objc public static var Name: String { "leaf" }
		/// The generator title
		@objc public static var Title: String { NSLocalizedString("pupilstyle.leaf", bundle: .localization, comment: "Leaf pupil generator title") }
		@objc public static func Create(_ settings: [String : Any]?) -> QRCodePupilShapeGenerator {
			Leaf()
		}

		/// Make a copy of the object
		@objc public func copyShape() -> QRCodePupilShapeGenerator { Leaf() }

		@objc public func settings() -> [String : Any] { [:] }
		@objc public func supportsSettingValue(forKey key: String) -> Bool { false }
		@objc public func setSettingValue(_ value: Any?, forKey key: String) -> Bool { false }

		/// The pupil centered in the 90x90 square
		@objc public func pupilPath() -> CGPath {
			let roundedPupil = CGPath.RoundedRect(
				rect: CGRect(x: 30, y: 30, width: 30, height: 30),
				cornerRadius: 6,
				byRoundingCorners: [.topRight, .bottomLeft]
			)
			return roundedPupil
		}
	}
}
