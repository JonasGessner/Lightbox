import UIKit
import AsyncDisplayKit

open class LightboxImage {

  open fileprivate(set) var image: UIImage?
  open fileprivate(set) var imageURL: URL?
  open fileprivate(set) var videoURL: URL?
  open fileprivate(set) var imageClosure: (() -> UIImage)?
  open var text: String

  // MARK: - Initialization

  internal init(text: String = "") {
    self.text = text
  }

  public init(image: UIImage, text: String = "", videoURL: URL? = nil) {
    self.image = image
    self.text = text
    self.videoURL = videoURL
  }

  public init(imageURL: URL, text: String = "", videoURL: URL? = nil) {
    self.imageURL = imageURL
    self.text = text
    self.videoURL = videoURL
  }

  public init(imageClosure: @escaping () -> UIImage, text: String = "", videoURL: URL? = nil) {
    self.imageClosure = imageClosure
    self.text = text
    self.videoURL = videoURL
  }

  open func addImageTo(_ imageNode: ASImageNode, completion: ((UIImage?) -> Void)? = nil) -> (() -> Void)? {
    if let image = image {
      imageNode.image = image
      completion?(image)
    } else if let imageURL = imageURL {
      var cancelOperation: (() -> Void)? = nil
      LightboxConfig.loadImage(imageNode, imageURL, &cancelOperation, completion)
      return cancelOperation
    } else if let imageClosure = imageClosure {
      let img = imageClosure()
      imageNode.image = img
      completion?(img)
    } else {
      imageNode.image = nil
      completion?(nil)
    }
    return nil
  }
}
