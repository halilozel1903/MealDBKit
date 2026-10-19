import Foundation
import Testing
@testable import MealDBKit

@Suite("Image and video URLs")
struct ImageTests {
    let photo = URL(string: "https://www.themealdb.com/images/media/meals/ustsqw1468250014.jpg")!

    @Test func mealPhotoSizes() {
        #expect(MealDBImages.mealImageURL(photo, size: .original) == photo)
        #expect(MealDBImages.mealImageURL(photo, size: .preview).absoluteString == "https://www.themealdb.com/images/media/meals/ustsqw1468250014.jpg/preview")
        #expect(MealDBImages.mealImageURL(photo, size: .small).absoluteString.hasSuffix(".jpg/small"))
        #expect(MealDBImages.mealImageURL(photo, size: .large).absoluteString.hasSuffix(".jpg/large"))
    }

    @Test func resizingAResizedPhotoReplacesTheSize() {
        let preview = MealDBImages.mealImageURL(photo, size: .preview)
        #expect(MealDBImages.mealImageURL(preview, size: .medium).absoluteString == "https://www.themealdb.com/images/media/meals/ustsqw1468250014.jpg/medium")
        #expect(MealDBImages.mealImageURL(preview, size: .original) == photo)
    }

    @Test func ingredientPictures() {
        #expect(MealDBImages.ingredientImageURL(name: "Lime", size: .original).absoluteString == "https://www.themealdb.com/images/ingredients/lime.png")
        #expect(MealDBImages.ingredientImageURL(name: "Lime").absoluteString == "https://www.themealdb.com/images/ingredients/lime-small.png")
        #expect(MealDBImages.ingredientImageURL(name: " Penne Rigate ", size: .large).absoluteString == "https://www.themealdb.com/images/ingredients/penne%20rigate-large.png")
        #expect(MealDBImages.ingredientImageURL(name: "Salt/Pepper").absoluteString == "https://www.themealdb.com/images/ingredients/salt%2Fpepper-small.png")
    }

    @Test func mealIngredientPicture() {
        let ingredient = MealIngredient(position: 1, name: "Parmigiano-Reggiano", measure: "spinkling")
        #expect(ingredient.imageURL().absoluteString == "https://www.themealdb.com/images/ingredients/parmigiano-reggiano-small.png")
    }

    @Test func youtubeIDs() {
        let links: [String: String] = [
            "https://www.youtube.com/watch?v=1IszT_guI08": "1IszT_guI08",
            "https://youtube.com/watch?feature=share&v=4aZr5hZXP_s": "4aZr5hZXP_s",
            "https://youtu.be/1IszT_guI08": "1IszT_guI08",
            "https://www.youtube.com/embed/1IszT_guI08": "1IszT_guI08",
            "https://www.youtube.com/shorts/abc123": "abc123",
        ]
        for (link, id) in links {
            #expect(MealDBImages.youtubeVideoID(in: URL(string: link)!) == id)
        }
        #expect(MealDBImages.youtubeVideoID(in: URL(string: "https://www.youtube.com/")!) == nil)
        #expect(MealDBImages.youtubeVideoID(in: URL(string: "https://vimeo.com/123")!) == nil)
        #expect(MealDBImages.youtubeThumbnailURL(videoID: "1IszT_guI08").absoluteString == "https://img.youtube.com/vi/1IszT_guI08/hqdefault.jpg")
    }
}
