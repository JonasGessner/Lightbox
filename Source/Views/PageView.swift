import UIKit
import AsyncDisplayKit

protocol PageViewDelegate: class {

  func pageViewDidZoom(_ pageView: PageView)
  func remoteImageDidLoad(_ image: UIImage?, imageNode: ASImageNode)
  func pageView(_ pageView: PageView, didTouchPlayButton videoURL: URL)
  func pageViewDidTouch(_ pageView: PageView)
}

class PageView: UIScrollView {

  lazy var imageNode: ASImageNode = {
    let imageNode = ASImageNode()
    imageNode.contentMode = .scaleAspectFit
    imageNode.clipsToBounds = true
    imageNode.isUserInteractionEnabled = true

    return imageNode
  }()

  lazy var playButton: UIButton = {
    let button = UIButton(type: .custom)
    button.frame.size = CGSize(width: 60, height: 60)
    button.setBackgroundImage(AssetManager.image("lightbox_play"), for: UIControl.State())
    button.addTarget(self, action: #selector(playButtonTouched(_:)), for: .touchUpInside)

    button.layer.shadowOffset = CGSize(width: 1, height: 1)
    button.layer.shadowColor = UIColor.gray.cgColor
    button.layer.masksToBounds = false
    button.layer.shadowOpacity = 0.8

    return button
  }()

  lazy var loadingIndicator: UIView = LightboxConfig.makeLoadingIndicator()

  var image: LightboxImage
  var contentFrame = CGRect.zero
  weak var pageViewDelegate: PageViewDelegate?

  private var cancelCurrentImageLoading: (() -> Void)?

  var hasZoomed: Bool {
    return zoomScale != 1.0
  }

  // MARK: - Initializers

  init(image: LightboxImage) {
    self.image = image
    super.init(frame: CGRect.zero)

    configure()

    fetchImage()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Configuration

  func configure() {
    addSubview(imageNode.view)

    updatePlayButton()

    addSubview(loadingIndicator)

    delegate = self
    isMultipleTouchEnabled = true
    minimumZoomScale = LightboxConfig.Zoom.minimumScale
    maximumZoomScale = LightboxConfig.Zoom.maximumScale
    showsHorizontalScrollIndicator = false
    showsVerticalScrollIndicator = false

    let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(scrollViewDoubleTapped(_:)))
    doubleTapRecognizer.numberOfTapsRequired = 2
    doubleTapRecognizer.numberOfTouchesRequired = 1
    addGestureRecognizer(doubleTapRecognizer)

    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:)))
    addGestureRecognizer(tapRecognizer)

    tapRecognizer.require(toFail: doubleTapRecognizer)
  }

  // MARK: - Update
  func update(with image: LightboxImage) {
    self.image = image
    updatePlayButton()
    fetchImage()
  }

  func updatePlayButton () {
    if self.image.videoURL != nil && !subviews.contains(playButton) {
      addSubview(playButton)
    } else if self.image.videoURL == nil && subviews.contains(playButton) {
      playButton.removeFromSuperview()
    }
  }

  // MARK: - Fetch
  private func fetchImage () {
    cancelCurrentImageLoading?()

    loadingIndicator.alpha = 1
    cancelCurrentImageLoading = self.image.addImageTo(imageNode) { [weak self] image in
      guard let self = self else {
        return
      }

      self.cancelCurrentImageLoading = nil

      self.isUserInteractionEnabled = true
      self.configureImageView()
      self.pageViewDelegate?.remoteImageDidLoad(image, imageNode: self.imageNode)

      UIView.animate(withDuration: 0.4) {
        self.loadingIndicator.alpha = 0
      }
    }
  }

  // MARK: - Recognizers

  @objc func scrollViewDoubleTapped(_ recognizer: UITapGestureRecognizer) {
    let pointInView = recognizer.location(in: imageNode.view)
    let newZoomScale = zoomScale > minimumZoomScale
      ? minimumZoomScale
      : maximumZoomScale

    let width = contentFrame.size.width / newZoomScale
    let height = contentFrame.size.height / newZoomScale
    let x = pointInView.x - (width / 2.0)
    let y = pointInView.y - (height / 2.0)

    let rectToZoomTo = CGRect(x: x, y: y, width: width, height: height)

    zoom(to: rectToZoomTo, animated: true)
  }

  @objc func viewTapped(_ recognizer: UITapGestureRecognizer) {
    pageViewDelegate?.pageViewDidTouch(self)
  }

  // MARK: - Layout

  override func layoutSubviews() {
    super.layoutSubviews()

    loadingIndicator.center = imageNode.view.center
    playButton.center = imageNode.view.center
  }

  func configureImageView() {
    guard let image = imageNode.image else {
        centerImageView()
        return
    }

    let imageViewSize = imageNode.frame.size
    let imageSize = image.size
    let realImageViewSize: CGSize

    if imageSize.width / imageSize.height > imageViewSize.width / imageViewSize.height {
      realImageViewSize = CGSize(
        width: imageViewSize.width,
        height: imageViewSize.width / imageSize.width * imageSize.height)
    } else {
      realImageViewSize = CGSize(
        width: imageViewSize.height / imageSize.height * imageSize.width,
        height: imageViewSize.height)
    }

    imageNode.frame = CGRect(origin: CGPoint.zero, size: realImageViewSize)

    centerImageView()
  }

  func centerImageView() {
    let boundsSize = contentFrame.size
    var imageViewFrame = imageNode.frame

    if imageViewFrame.size.width < boundsSize.width {
      imageViewFrame.origin.x = (boundsSize.width - imageViewFrame.size.width) / 2.0
    } else {
      imageViewFrame.origin.x = 0.0
    }

    if imageViewFrame.size.height < boundsSize.height {
      imageViewFrame.origin.y = (boundsSize.height - imageViewFrame.size.height) / 2.0
    } else {
      imageViewFrame.origin.y = 0.0
    }

    imageNode.frame = imageViewFrame
  }

  // MARK: - Action

  @objc func playButtonTouched(_ button: UIButton) {
    guard let videoURL = image.videoURL else { return }

    pageViewDelegate?.pageView(self, didTouchPlayButton: videoURL as URL)
  }
}

// MARK: - LayoutConfigurable

extension PageView: LayoutConfigurable {

  @objc func configureLayout() {
    contentFrame = frame
    contentSize = frame.size
    imageNode.frame = frame
    zoomScale = minimumZoomScale

    configureImageView()
  }
}

// MARK: - UIScrollViewDelegate

extension PageView: UIScrollViewDelegate {

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return imageNode.view
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    centerImageView()
    pageViewDelegate?.pageViewDidZoom(self)
  }
}
