class Source {
  final int id;
  final String name;
  final String url;

  const Source({
    required this.id,
    required this.name,
    required this.url,
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id'] as int,
      name: json['name'] as String,
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
    };
  }

  @override
  String toString() {
    return 'Source{id: $id, name: $name, url: $url}';
  }
}

// The two daily recordings used to be addressed by fixed URL from here. They
// now live on DailyAsset in sgpc_day.dart, which keeps the undated address as
// a last resort and prefers the dated archive, so that a cache key is a day
// rather than a filename that means something different every morning.

const kLiveKirtanUrl = "http://live.sgpc.net:7339/;";
const kLiveKirtanUrlWeb = "https://live.sgpc.net:8442/;";
