\name{ProFound-package}
\alias{ProFound-package}
\alias{ProFound}
\docType{package}
\title{
\packageTitle{ProFound}
}
\description{
\packageDescription{ProFound}
}
\details{
\tabular{ll}{
Package: \tab ProFound\cr
Type: \tab Package\cr
Version: \tab 1.3.4\cr
Date: \tab 2018-11-12\cr
License: \tab LGPL-3\cr
Depends: \tab R (>= 3.0), FITSio, magicaxis (>= 2.0.3)\cr
Imports: \tab RColorBrewer, data.table, celestial (>= 1.4.1)\cr
Suggests: \tab ProFit, knitr, rmarkdown, EBImage, akima, imager, LaplacesDemon\cr
}
}

\author{
\packageAuthor{ProFound}

Maintainer: \packageMaintainer{ProFound}
}
\references{
Robotham A.S.G., et al., 2018, MNRAS, 476, 3137
}
\keyword{profile}

\examples{
\dontrun{
image=readFITS(system.file("extdata", 'VIKING/mystery_VIKING_Z.fits',
package="ProFound"))

profound=profoundProFound(image, skycut=1.5, magzero=30, verbose=TRUE, plot=TRUE)
}
}
