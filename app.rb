require 'httparty'
require 'json'
require 'fileutils'

# Classe que rastreia a contagem de erros e sucessos por caminho de URL em um arquivo de log.
class PathTracker
  # URL do arquivo de log a ser lido.
  LOG_URL = 'https://s3.amazonaws.com/gupy5/production/companies/41683/emails/1679436955729/2c36bc50-c810-11ed-9aa6-a37a97984945/log.txt'.freeze

  # Inicializa um novo objeto PathTracker, lê os logs do arquivo de log e imprime a contagem formatada de erros e sucessos por caminho de URL.
  def initialize
    logs = get_logs(LOG_URL)
    log_count = count_logs(logs)
    result = format_result(log_count)

    puts "\n #{'-' * 4} Output of Logs Grouped by Path #{'-' * 4}"
    puts "\n#{JSON.pretty_generate(result)}"
    puts "\n #{'-' * 40}"

    save_output_to_file(JSON.pretty_generate(result))
  end

  # Retorna uma matriz de strings contendo os logs lidos do arquivo de log na URL fornecida.
  # Se ocorrer um erro, uma mensagem de erro será exibida e uma matriz vazia será retornada.
  def get_logs(url)
    response = HTTParty.get(url)
    handle_response(response)
  rescue StandardError => e
    puts "An error occurred: #{e.message}"
    []
  end

  # Lida com a resposta HTTP da solicitação GET e retorna o corpo da resposta se o código de status estiver na faixa de 200 a 399.
  # Caso contrário, lança uma exceção com a mensagem de erro correspondente.
  def handle_response(response)
    case response.code
    when 500
      raise StandardError, 'Server error 500'
    when 200..399
      response.body.split("\n")
    else
      raise StandardError, "Unexpected response code #{response.code}"
    end
  end

  # Conta o número de erros e sucessos por caminho de URL nos logs fornecidos e retorna um hash de contagem.
  def count_logs(logs)
    log_count = Hash.new { |h, k| h[k] = { path: k, error_count: 0, success_count: 0 } }
    logs.each do |log|
      parse_log(log).tap do |data|
        log_count[data['path']][data['statusCode'].to_i.between?(200, 399) ? :success_count : :error_count] += 1
      end
    end
    log_count
  end

  # Analisa um único registro de log no formato JSON e retorna um hash com as chaves "path" e "statusCode".
  def parse_log(log)
    JSON.parse(log.tr("'", '\"'))
  end

  # Formata o resultado da contagem de logs em uma matriz de hashes, cada um representando uma contagem por caminho de URL.
  def format_result(log_count)
    log_count.values
  end

  # Salva o conteúdo de `output` em um arquivo JSON formatado em ~/sre-intern-test/output.json
  def save_output_to_file(output)
    output_path = File.expand_path('sre-intern-test/output.json')
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, JSON.pretty_generate(output))
  end
end

PathTracker.new
