# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'rspec'

require_relative '../app'

describe LogPathGrouper do
  let(:test_logs_url) { 'tests/test_logs.txt' }
  let(:output_file_path) { File.expand_path('sre-intern-test/output.json') }

  before do
    allow(HTTParty).to receive(:get).and_return(OpenStruct.new(code: 200, body: File.read(test_logs_url)))
  end

  after do
    FileUtils.rm_rf(File.dirname(output_file_path))
  end

  describe '#initialize' do
    subject { described_class.new }

    it 'reads logs, processes them and saves the result to the output file' do
      expect(File).to exist(output_file_path)
    end
  end

  describe '#get_logs' do
    subject { described_class.new.get_logs(test_logs_url) }

    it 'returns an array of logs' do
      expect(subject).to be_a(Array)
      expect(subject.length).to eq(1000)
    end
  end

  describe '#handle_response' do
    let(:response) { OpenStruct.new(code: response_code, body: File.read(test_logs_url)) }
    subject { described_class.new.handle_response(response) }

    context 'when the response code is 200' do
      let(:response_code) { 200 }

      it 'returns an array of logs' do
        expect(subject).to be_a(Array)
        expect(subject.length).to eq(1000)
      end
    end

    context 'when the response code is 500' do
      let(:response_code) { 500 }

      it 'raises a StandardError with a server error message' do
        expect { subject }.to raise_error(StandardError, 'Server error 500')
      end
    end

    context 'when the response code is unexpected' do
      let(:response_code) { 404 }

      it 'raises a StandardError with an unexpected response code message' do
        expect { subject }.to raise_error(StandardError, "Unexpected response code #{response_code}")
      end
    end
  end

  describe '#count_logs' do
    let(:logs) { File.read(test_logs_url).split("\n") }
    subject { described_class.new.count_logs(logs) }

    it 'returns a hash of log counts by path' do
      expect(subject).to eq(
        {
          '/' => { error_count: 243, path: '/', success_count: 1 },
          '/api/path3' => { error_count: 250, path: '/api/path3', success_count: 2 },
          '/path1' => { error_count: 248, path: '/path1', success_count: 0 },
          '/path2' => { error_count: 255, path: '/path2', success_count: 1 }
        }
      )
    end
  end

  describe '#parse_log' do
    let(:log) do
      '{"env": "prod", "path": "/", "method": "DELETE", "duration": "163", "statusCode": "469", "statusMessage": "status message 2", "host": "queroteste.com", "level": "LEVEL 1", "message": "message 3", "timestamp": "1679339588.557135"}'
    end

    subject { described_class.new.parse_log(log) }

    it 'returns a hash with "path" and "statusCode" keys' do
      expect(subject).to eq(
        {
          'duration' => '163',
          'env' => 'prod',
          'host' => 'queroteste.com',
          'level' => 'LEVEL 1',
          'message' => 'message 3',
          'method' => 'DELETE',
          'path' => '/',
          'statusCode' => '469',
          'statusMessage' => 'status message 2',
          'timestamp' => '1679339588.557135'
        }
      )
    end
  end

  describe '#format_result' do
    let(:log_count) do
      {
        '/' => { path: '/', error_count: 0, success_count: 0 },
        '/path1' => { path: '/path1', error_count: 0, success_count: 0 },
        '/path2' => { path: '/path2', error_count: 0, success_count: 0 },
        '/api/path3' => { path: '/api/path3', error_count: 0, success_count: 0 }
      }
    end

    subject { described_class.new.format_result(log_count) }

    it 'returns an array of hashes representing the count for each URL path' do
      expect(subject).to eq(
        [
          { path: '/', error_count: 0, success_count: 0 },
          { path: '/path1', error_count: 0, success_count: 0 },
          { path: '/path2', error_count: 0, success_count: 0 },
          { path: '/api/path3', error_count: 0, success_count: 0 }
        ]
      )
    end
  end

  describe '#save_output_to_file' do
    let(:output) { JSON.pretty_generate([{ path: '/', error_count: 0, success_count: 0 }]) }
    subject { described_class.new.save_output_to_file(output) }

    it 'saves the output to a JSON file at the specified path' do
      subject

      expect(File).to exist(output_file_path)
      expect(JSON.parse(File.read(output_file_path))).to eq("[\n  {\n    \"path\": \"/\",\n    \"error_count\": 0,\n    \"success_count\": 0\n  }\n]")
    end
  end
end
