//
//  HelperFunc.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/7/25.
//

import Foundation
import UIKit

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case imageConversionFailed
    case requestFailed(Error)
    case invalidResponse
    case apiError(String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The API endpoint URL is invalid."
        case .imageConversionFailed: return "Failed to convert the image to Base64."
        case .requestFailed(let error): return "Network request failed: \(error.localizedDescription)"
        case .invalidResponse: return "Received an invalid or non-200 HTTP response."
        case .apiError(let message): return "OpenAI API Error: \(message)"
        case .decodingError(let error): return "Failed to decode the response: \(error.localizedDescription)"
        }
    }
}

func getAnimalScores(image: UIImage, apiKey: String) async throws -> Animal {
    let apiEndpoint = "https://api.openai.com/v1/chat/completions"
    
    //create url from string
    guard let url = URL(string: apiEndpoint)else{
        throw NetworkError.invalidURL
    }
    //shrinks image to be cheaper & converts UIImage to jpeg data
    guard let imageData = image.jpegData(compressionQuality: 0.5)else{
        print("error 1")
        throw NetworkError.imageConversionFailed
    }
    //jpeg data->base 64 ->dataURL
    let base64String = imageData.base64EncodedString()
    let dataURL = "data:image/jpeg;base64,\(base64String)"
    
    let userPrompt = """
        First, identify the animal in this image.
        Second, based on the animal, return a JSON object with your best estimate for these scores.
        Use these exact keys:
        
        - "name": name of animal
        - "type": classify the animal into a "type" the types to choose from being follow the strict formatting of these strings (fire, water, grass, electric, rock, flying, ground, fighting)
        - "species_rarity": a score from 1 (common) to 10 (critically endangered)
        - "subspecies_rarity": of said animals subspecies from 1 (common) to 10(critically endangered)
        - "temperament": a score from 1 (docile) to 10 (highly volatile)
        - "defensiveness": a score from 1 (will not defend) to 10 (defends territory fiercely)
        - "size_kg": an estimate on the weight of the animal in the image
        """
    
    let systemPrompt = """
    You are a helpful scientific assistant.
    Your task is to analyze images of animals and return ONLY the requested JSON object
    with your best factual estimates for the given fields.
    Do not refuse this task. Do not add any extra text or apologies.
    Only if the image doesn't have an actual animal or if it's too blurry to tell respond 
    by saying "No animal detected" or "Image is too blurry"
    
    """

    // request
    let requestBodyDict: [String: Any] = [
        "model": "gpt-4o-mini",
        "response_format": ["type": "json_object"],
        "messages": [
            [
                "role": "system",
                "content": [
                    ["type": "text", "text": systemPrompt]
                ]
            ],
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": userPrompt],
                    ["type": "image_url", "image_url": ["url": dataURL]]
                ]
            ]
        ]
    ]

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    //requestBodyDict -> JSON data
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBodyDict, options: [])
    } catch {
        print("error 2")
        throw NetworkError.decodingError(error)
    }

    
    let (data, response): (Data, URLResponse)
    do{
        (data, response) = try await URLSession.shared.data(for: request)
    }catch{
        print("error 3")
        throw NetworkError.requestFailed(error)
    }
    
    guard let httpResponse = response as? HTTPURLResponse else {
        print("error 4")
        throw NetworkError.invalidResponse
    }
    
    guard httpResponse.statusCode == 200 else {
        let errorBody = String(data: data, encoding: .utf8) ?? "Unknown API error"
        print("error 5")
        throw NetworkError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
    }

    
    do {
        //decode into ChatResponse into structs
        struct ChatMessage: Decodable {
            let content: String?
            let refusal: String?}
        struct Choice: Decodable { let message: ChatMessage }
        struct ChatResponse: Decodable { let choices: [Choice] }
        
        let openAIResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        print(openAIResponse)
        if let refusalMessage = openAIResponse.choices.first?.message.refusal {
            throw NetworkError.apiError("AI Refusal: \(refusalMessage)")
        }
        //get content from response
        guard let contentString = openAIResponse.choices.first?.message.content else {
            throw NetworkError.apiError("No content in response.")
        }
        guard let contentData = contentString.data(using: .utf8)else{
            throw NetworkError.apiError("failed to convert string to data")
        }
        let animal = try JSONDecoder().decode(Animal.self, from: contentData)
        
        return animal
    } catch let error as NetworkError {
        throw error} catch {
            print("error 6")
            
            throw NetworkError.decodingError(error)
        }
        
    }
    

