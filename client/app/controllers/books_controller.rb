# frozen_string_literal: true

require 'grpc'
require 'books_services_pb'

# BookController is a controller for handling books requests
class BooksController < ApplicationController
  def index
    response = stub.get_books(Books::EmptyParams.new).to_h
    render json: { data: response[:books] }
  end

  def show
    response = stub.get_book(Books::BookID.new(id: params[:id].to_i)).to_h
    render json: { data: response }
  rescue GRPC::NotFound => e
    render json: Books::BookNotFound.new(message: 'Book not found')
  end

  private

  def stub
    # RubyLogger defines a logger for gRPC based on the standard ruby logger.
    module RubyLogger
      def logger
        LOGGER
      end

      LOGGER = Logger.new(STDOUT)
      LOGGER.level = Logger::DEBUG
    end

    # GRPC is the general RPC module
    module GRPC
      # Inject the noop #logger if no module-level logger method has been injected.
      extend RubyLogger
    end


    require 'books_services_pb'
    stub_retry = Books::BookService::Stub.new('localhost:50051', :this_channel_is_insecure, timeout: 10, channel_args: {
      "grpc.enable_retries" => 1,
      "grpc.service_config" => JSON.generate(
        methodConfig: [
          {
            name: [{service: "books.BookService"}],
            retryPolicy: {
              retryableStatusCodes: ["UNAVAILABLE", "INTERNAL", "UNKNOWN", "NOT_FOUND"],
              maxAttempts: 3,
              initialBackoff: "1s",
              backoffMultiplier: 2.0,
              maxBackoff: "0.3s"
            }
          }
        ]
      )
    })
    r = stub_retry.get_books(Books::EmptyParams.new).to_h
    r = stub_retry.get_book(Books::BookID.new(id: 69))

    begin
      r = stub_retry.get_book(Books::BookID.new(id: 69))
    rescue GRPC::NotFound  => e
      puts "operation cancel called - #{e} - #{e.to_status}"
    end

    stub = Books::BookService::Stub.new('localhost:50051', :this_channel_is_insecure, channel_args: {
      "grpc.enable_retries" => 1,
      "grpc.service_config" => JSON.generate(
        methodConfig: [
          {
            name: [
              {
                service: "books.BookService",
                method: "GetBooks"
              }
            ],
            retryPolicy: {
              retryableStatusCodes: ["UNAVAILABLE"],
              maxAttempts: 3,
              initialBackoff: "0.1s",
              backoffMultiplier: 2.0,
              maxBackoff: "0.3s"
            }
          }
        ]
      )
    })
    stub.get_books(Books::EmptyParams.new).to_h

    stub2 = Books::BookService::Stub.new('localhost:50051', :this_channel_is_insecure)
    stub2.get_books(Books::EmptyParams.new).to_h
  rescue GRPC::BadStatus => e
    abort "ERROR: #{e.message}"
  end
end
